subdir('icons')

desktop_file = i18n.merge_file(
	input: configure_file(
		input: 'org.altlinux.Tailor.desktop.in.in',
		output: 'org.altlinux.Tailor.desktop.in',
		configuration: {'APP_ID': application_id, 'NAME_SUFFIX': name_suffix}
	),
	output: application_id + '.desktop',
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
	input: configure_file(
		input: 'org.altlinux.Tailor.metainfo.xml.in.in',
		output: 'org.altlinux.Tailor.metainfo.xml.in',
		configuration: {'APP_ID': application_id}
	),
	output: application_id + '.metainfo.xml',
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

gresource_xml = configure_file(
	input: 'org.altlinux.Tailor.gresource.xml.in',
	output: application_id + '.gresource.xml',
	configuration: {'APP_ID': application_id}
)

blueprint_compiler = find_program('blueprint-compiler')
app_resources = gnome.compile_resources(
	'app_resources',
	gresource_xml,
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

blueprint_lint_rules = [
  'adjustment_prop_order',
  'gtk_switch_state',
  'missing_descriptive_text',
  'number_of_children',
  'translate_display_string',
  'unused_widget',
  'use_adw_bin',
  'use_styles',
  'use_unicode',
  'wrong_parent',
  'visible_true',
]

if blueprint_compiler.found()
	test(
		'Lint blueprints',
		blueprint_compiler,
		args: [
			'lint',
			'--rules=' + ','.join(blueprint_lint_rules),
			blueprints
		]
	)
endif

install_data(
	base_id + '.gschema.xml',
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
