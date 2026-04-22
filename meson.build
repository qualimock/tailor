project(
	'Tailor',
	['c', 'vala'],
	version: '0.1.0',
	meson_version: '>= 1.10',
)

id = 'org.altlinux.Tailor'
name = meson.project_name()
version = meson.project_version()
basename = name.to_lower()

add_project_arguments(
	'-w', '-DGETTEXT_PACKAGE="@0@"'.format(basename),
	language: 'c'
)

gnome = import('gnome')
i18n = import('i18n')

config = configuration_data()
config.set('ID', id)
config.set('VERSION', version)
config.set('GETTEXT_PACKAGE', basename)
config.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config.set('DATADIR', get_option('prefix') / get_option('datadir') / basename)

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
	glib_compile_schemas: true,
	gtk_update_icon_cache: true,
	update_desktop_database: true
)
