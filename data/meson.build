subdir('icons')

desktop_file = i18n.merge_file(
	input: id + '.desktop.in',
	output: id + '.desktop',
	po_dir: meson.project_source_root() / 'po',
	type: 'desktop',
	install: true,
	install_dir: get_option('datadir') / 'applications'
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
	test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstream_file = i18n.merge_file(
	input: id + '.metainfo.xml.in',
	output: id + '.metainfo.xml',
	po_dir: meson.project_source_root() / 'po',
	install: true,
	install_dir: get_option('datadir') / 'metainfo'
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
	test(
		'Validate appstream file',
		appstreamcli,
		args: ['validate', appstream_file]
	)
endif

subdir('ui')

blueprint_compiler = find_program('blueprint-compiler')
app_resources = gnome.compile_resources(
	'app_resources',
	id + '.gresource.xml',
	source_dir: meson.current_build_dir(),
	dependencies: [
		custom_target(
			'blueprints',
			input: blueprints,
			output: '.',
			command: [ blueprint_compiler, 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@' ]
		),
		appstream_file,
	]
)
if blueprint_compiler.found()
	test(
		'Lint blueprints',
		blueprint_compiler,
		args: ['lint', blueprints]
	)
endif

install_data(
	id + '.gschema.xml',
	install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
	test(
		'Validate schema file',
		compile_schemas,
		args: ['--strict', '--dry-run', meson.current_source_dir()]
	)
endif
