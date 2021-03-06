part of item;

class Note {
	@Field() int id;
	@Field() String username;
	@Field() String title;
	@Field() String body;
	@Field() DateTime timestamp;

	Note();
	Note.create(this.username, String title, this.body, [this.id]) {
		title = title.trim();
		if (title.length > NoteManager.title_length_max) {
			title = title.substring(0, NoteManager.title_length_max - 1);
		}
		this.title = title;
	}

	Map<String, dynamic> toMap() => {
		"id": id,
		"username": username,
		"title": title,
		"body": body,
		"timestamp": timestamp.toString()
	};

	@override
	String toString() => "<Note '$title' by '$username'>";
}

@app.Group("/note")
class NoteManager {
	static final int title_length_max = 30; // Also set by HTML in client
	static final String tool_item = "quill";
	static final String paper_item = "paper";
	static final String note_item = "note";
	static final String fortune_cookie_item = "fortune_cookie";
	static final String fortune_cookie_withfortune_item = "fortune_cookie_withfortune";
	static final String fortune_item = "fortune";
	static final String writing_skill = "penpersonship";

	static Future<Note> find(int id) async {
		PostgreSql dbConn = await dbManager.getConnection();

		try {
			return (await dbConn.query(
				"SELECT * FROM notes WHERE id = @id",
				Note, {"id": id}
			)).single;
		} catch (e, st) {
			Log.error('Could not find note $id', e, st);
			return null;
		} finally {
			dbManager.closeConnection(dbConn);
		}
	}

	static Future<Note> add(Note note) async {
		PostgreSql dbConn = await dbManager.getConnection();

		if (note.id == null || note.id == -1) {
			// Adding a new note
			try {
				return (await dbConn.query(
					"INSERT INTO notes (username, title, body) "
						"VALUES (@username, @title, @body) RETURNING *",
					Note, {"username": note.username.trim(), "title": note.title.trim(), "body": note.body}
				)).single;
			} catch (e, st) {
				Log.error('Could not add note $note', e, st);
				return null;
			} finally {
				dbManager.closeConnection(dbConn);
			}
		} else {
			// Updating an existing note
			try {
				return (await dbConn.query(
					"UPDATE notes SET title = @title, body = @body "
						"WHERE id = @id RETURNING *",
					Note, {"id": note.id, "title": note.title.trim(), "body": note.body}
				)).single;
			} catch (e, st) {
				Log.error('Could not edit note $note', e, st);
				return null;
			} finally {
				dbManager.closeConnection(dbConn);
			}
		}
	}

	static Future<Map> addFromClient(Map noteData) async {
		try {
			String email = await User.getEmailFromUsername(noteData["username"]);
			Note created = new Note.create(noteData["username"], noteData["title"], noteData["body"], noteData["id"]);

			if (created.id != -1 && await SkillManager.getLevel(writing_skill, email) == 0) {
				// Trying to edit a note without the required skill
				return ({"error": "You don't know enough about Penpersonship to edit notes yet!"});
			}

			// Add data to database
			Note added = await add(created);

			if (created.id == -1) {
				// A new note!

				// Add item to inventory
				if (await InventoryV2.takeAnyItemsFromUser(email, paper_item, 1) != 1) {
					// Missing paper from inventory (dropped between quill action and saving note?)
					return ({"error": "You ran out of paper!"});
				}

				Item newNoteItem = getItem(added);

				if (await InventoryV2.addItemToUser(email, newNoteItem.getMap(), 1) != 1) {
					// No empty slot to fit new note, refund paper
					await InventoryV2.addItemToUser(email, items[paper_item].getMap(), 1);
					return ({"error": "There's no room for this note in your inventory!"});
				}

				// Increase skill
				SkillManager.learn(writing_skill, email);
			}

			// Send OK to client
			return added.toMap();
		} catch (e, st) {
			Log.error("Couldn't create note with $noteData", e, st);
			return ({"error": "Something went wrong :("});
		}
	}

	static Item getItem(Note note) {
		return new Item.clone(note_item)
			..metadata.addAll({"note_id": note.id.toString()})
			..metadata.addAll({"title": note.title});
	}

	@app.Route("/find/:id")
	Future<String> appFind(int id) async => JSON.encode((await find(id)).toMap());
}
