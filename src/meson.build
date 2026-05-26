app_sources = files(
	'main.vala',
	'application.vala',
	'service-context.vala',

	'ui' / 'main-window.vala',
	'ui' / 'home-page.vala',
	'ui' / 'write-page.vala',
	'ui' / 'devices-page.vala',
	'ui' / 'download-page.vala',
	'ui' / 'device-card.vala',
	'ui' / 'os-page.vala',
	'ui' / 'image-page.vala',

	'osinfo' / 'osinfo-provider.vala',
	'osinfo' / 'osinfo-service.vala',
	'osinfo' / 'os-mapper.vala',
	'osinfo' / 'os.vala',
	'osinfo' / 'os-family.vala',

	'usb' / 'usb-provider.vala',
	'usb' / 'usb-service.vala',
	'usb' / 'usb-mapper.vala',
	'usb' / 'usb-device.vala',

) + configure_file(
	input: 'build.vala.in',
	output: 'build.vala',
	configuration: config
) + app_resources

app_dependencies = [
	dependency('libadwaita-1'),
	dependency('libosinfo-1.0'),
	dependency('gee-0.8'),
	dependency('gio-2.0'),
	dependency('udisks2'),
]

executable(
	basename,
	sources: app_sources,
	dependencies: app_dependencies,
	vala_args: ['--pkg=posix'],
	install: true
)

vala_lint = find_program('vala-lint', required: false)
if vala_lint.found()
	test(
		'Lint vala files',
		vala_lint,
		args: [
			'--config', meson.project_source_root() / 'vala-lint.conf',
			meson.current_source_dir()
		]
	)
endif
