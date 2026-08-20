project(
	'Tailor',
	['c', 'vala'],
	version: '0.1.0',
	meson_version: '>= 1.1',
)

base_id = 'org.altlinux.Tailor'
profile = get_option('profile')

if profile == 'development'
	application_id = base_id + '.Devel'
	name_suffix = ' (Development)'
else
	application_id = base_id
	name_suffix = ''
endif

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
config.set('ID', application_id)
config.set('BASE_ID', base_id)
config.set('PROFILE', profile)
config.set('NAME_SUFFIX', name_suffix)
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
