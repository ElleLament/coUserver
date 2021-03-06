part of entity;

class EarthshakerRespawningItem extends RespawningItem {
	EarthshakerRespawningItem(String id, num x, num y, String streetName) : super(id, x, y, streetName) {
		type = 'Earthshaker';
		itemType = 'earthshaker';
		respawnTime = new Duration(minutes: 5);

		states = {
			'1-2-3-4': new Spritesheet('1-2-3-4',
				'http://childrenofur.com/assets/entityImages/earthshaker__x1_1_x1_2_x1_3_x1_4_png_1354829806.png',
				144, 46, 36, 46, 4, true)
		};

		setState('1-2-3-4');
		maxState = 3;
	}
}
