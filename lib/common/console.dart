library console;

import 'dart:async';
import 'dart:io';

import 'package:coUserver/achievements/stats.dart';
import 'package:coUserver/common/util.dart';
import 'package:coUserver/endpoints/chat_handler.dart';
import 'package:coUserver/endpoints/inventory_new.dart';
import 'package:coUserver/endpoints/status.dart';
import 'package:coUserver/entities/items/item.dart';

class Console {
	static void _registerCommands() {
		new Command.register('help', () {
			Log.command('List of commands & arguments:');
			for (Command command in _commands.values) {
				Log.command('* $command');
			}
		});

		new Command.register('status', () async {
			(Console.formatMap(
				await getServerStatus()
					..addAll({'pid': pid})
			)).split('\n').forEach((String ln) => Log.command(ln));
		});

		new Command.register('stop', (String exitCode) async {
			await cleanup(int.parse(exitCode));
		}, ['exit code']);

		new Command.register('global', (String message) async {
			ChatHandler.superMessage(message);
			Log.command('Sent message to Global Chat (${ChatHandler.users.length} online)');
		}, ['message to post in global chat']);

		new Command.register('migrate', (String object) async {
			final Map<String, Function> _MIGRATES = {
				'entities': () async => await StreetEntities.migrateEntities()
			};

			if (_MIGRATES.keys.contains(object)) {
				Log.command('Migrating $object...');
				int migrated = await _MIGRATES[object]();
				Log.command('Migration of $migrated $object completed!');
			} else {
				Log.command('No migrateable object "$object"');
			}
		}, ['object to migrate']);

		new Command.register('giveItem', (String email, String itemType) async {
			if (!items.containsKey(itemType)) {
				Log.command('No such item: $itemType');
			} else {
				if ((await InventoryV2.addItemToUser(email, items[itemType].getMap(), 1)) == 1) {
					Log.command("Successfully added $itemType to <email=$email>'s inventory");
				} else {
					Log.command("Error adding $itemType to <email=$email>'s inventory'");
				}
			}
		}, ['user email', 'item type']);

		new Command.register('useTool', (String email, String itemType, String amount) async {
			if (await InventoryV2.decreaseDurability(email, itemType, amount: int.parse(amount))) {
				Log.command("Successfully took $amount durability from <email=$email>'s $itemType");
			} else {
				Log.command("Error taking $amount durability from <email=$email>'s $itemType");
			}
		}, ['user email', 'tool item type', 'durability to use']);

		new Command.register('stats', () async {
			Console.formatMap(await StatManager.getAllSums())
				.split('\n').forEach((String ln) => Log.command(ln));
		});
	}

	static final String ARG_GROUP = '"';

	static Map<String, Command> _commands = new Map();

	static StreamSubscription _handler;

	static void init() {
		// Graceful shutdown
		ProcessSignal.SIGINT.watch().listen((ProcessSignal sig) async => await cleanup());
		ProcessSignal.SIGTERM.watch().listen((ProcessSignal sig) async => await cleanup());

		stdin.echoMode = true;
		stdin.lineMode = true;

		_handler?.cancel();
		_handler = stdin.listen((List<int> chars) async {
			String input = new String.fromCharCodes(chars).trim();
			if (input.length > 0) {
				Log.command('> $input');
				try {
					await _runCommand(input);
				} catch (e) {
					Log.command('Error running command: $e');
				}
			}
		});

		_registerCommands();
	}

	static String formatMap(Map input) {
		StringBuffer output = new StringBuffer();
		input.forEach((key, value) {
			output.writeln('$key: $value');
		});
		return output.toString().trim();
	}

	static void registerCommand(Command command) {
		if (_commands.containsKey(command.name)) {
			throw 'Command ${command.name} already registered';
		} else {
			_commands[command.name] = command;
		}
	}

	static Future<dynamic> _runCommand(String input) async {
		List<String> parts = input.split(' ');
		List<String> args = parts.sublist(1);
		List<String> grouped = new List();

		// Merge arguments between ARG_GROUP into one argument
		bool inGroup = false;
		for (int i = 0; i < args.length; i++) {
			if (args[i].startsWith(ARG_GROUP)) {
				// Beginning of a group
				grouped.add(args[i].substring(ARG_GROUP.length));
				inGroup = true;
			} else if (args[i].endsWith(ARG_GROUP)) {
				// End of a group
				grouped[grouped.length - 1] += ' ' + args[i].substring(
					0, args[i].length - ARG_GROUP.length);
				inGroup = false;
			} else if (inGroup) {
				// Inside of a group, add to previous part
				grouped[grouped.length - 1] += ' ' + args[i];
			} else {
				// Not inside a group, new argument
				grouped.add(args[i]);
			}
		}
		args = grouped;

		String name = parts.first;
		if (!_commands.containsKey(name)) {
			throw 'Command $name not found';
		} else {
			return await _commands[name].call(args);
		}
	}
}

class Command {
	String _name;
	List<String> _arguments;
	Function _function;

	String get name => _name;

	Command(String name, Function function, [List<String> arguments]) {
		_name = name;
		_arguments = arguments ?? new List();
		_function = function;
	}

	Command.register(String name, Function function, [List<String> arguments]) {
		Console.registerCommand(new Command(name, function, arguments));
	}

	Future<dynamic> call(List<String> arguments) async {
		if (arguments.length != _arguments.length) {
			throw 'Incorrect number of arguments provided to $_name';
		}

		return await Function.apply(_function, arguments);
	}

	@override
	String toString() {
		String argFmt = (_arguments.length == 0 ? '' : '<${_arguments.join(', ')}>');
		return '$_name $argFmt';
	}
}
