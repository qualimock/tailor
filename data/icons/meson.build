icons_dir = get_option('datadir') / 'icons'

scalable_dir = 'hicolor' / 'scalable' / 'apps'
install_data(
	scalable_dir / '@0@.svg'.format(id),
	install_dir: icons_dir / scalable_dir
)

symbolic_dir = 'hicolor' / 'symbolic' / 'apps'
install_data(
	symbolic_dir / '@0@-symbolic.svg'.format(id),
	install_dir: icons_dir / symbolic_dir
)

actions_dir = 'hicolor' / 'symbolic' / 'actions'
actions_icons = files(
	actions_dir / 'drawer-symbolic.svg',
	actions_dir / 'download-symbolic.svg',
)
install_data(
	actions_icons,
	install_dir: icons_dir / actions_dir
)

