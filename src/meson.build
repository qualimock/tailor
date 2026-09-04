app_sources = files(
	'main.vala',
	'application.vala',

	'service' / 'service-context.vala',
	'service' / 'availability-checker.vala',
	'service' / 'checksum-resolver.vala',
	'service' / 'checksum-fetcher.vala',

	'service' / 'operation' / 'device-handle.vala',

	'service' / 'operation' / 'operation.vala',
	'service' / 'operation' / 'restore-operation.vala',
	'service' / 'operation' / 'flash-operation.vala',
	'service' / 'operation' / 'download-operation.vala',

	'ui' / 'ui-service.vala',
	'ui' / 'main-window.vala',
	'ui' / 'home-page.vala',
	'ui' / 'write-page.vala',
	'ui' / 'devices-page.vala',
	'ui' / 'download-page.vala',
	'ui' / 'download-page-row.vala',
	'ui' / 'device-card.vala',
	'ui' / 'os-page.vala',
	'ui' / 'image-page.vala',
	'ui' / 'status-line.vala',
	'ui' / 'progress-line.vala',
	'ui' / 'flash-page.vala',
	'ui' / 'status-page-with-badge.vala',
	'ui' / 'button-card.vala',

	'osinfo' / 'osinfo-provider.vala',
	'osinfo' / 'osinfo-service.vala',
	'osinfo' / 'os-parser.vala',
	'osinfo' / 'os-mapper.vala',
	'osinfo' / 'os-image.vala',
	'osinfo' / 'os-version.vala',
	'osinfo' / 'os-edition.vala',
	'osinfo' / 'os-family.vala',

	'usb' / 'usb-provider.vala',
	'usb' / 'usb-service.vala',
	'usb' / 'usb-device.vala',

) + configure_file(
	input: 'build.vala.in',
	output: 'build.vala',
	configuration: config
) + app_resources

if host_machine.system() == 'windows'
	app_sources += files(
		'usb' / 'usb-provider-windows.vala',
		'service' / 'operation' / 'device-handle-windows.vala',
		'service' / 'operation' / 'flash-pipe-windows.vala',
	)
	vala_platform_args = [
		'--vapidir=' + meson.project_source_root() / 'vapi',
		'--pkg=win32-storage',
		'--define=WINDOWS',
	]
	platform_link_args = ['-lsetupapi']
else
	app_sources += files(
		'usb' / 'usb-provider-linux.vala',
		'usb' / 'usb-mapper.vala',
		'service' / 'operation' / 'device-handle-linux.vala',
	)
	vala_platform_args = ['--pkg=posix']
	platform_link_args = []
endif

app_dependencies = [
	dependency('libadwaita-1'),
	dependency('libosinfo-1.0'),
	dependency('gee-0.8'),
	dependency('gio-2.0'),
	dependency('libsoup-3.0'),
]

if host_machine.system() != 'windows'
	app_dependencies += dependency('udisks2')
	app_dependencies += dependency('gio-unix-2.0')
endif

executable(
	basename,
	sources: app_sources,
	dependencies: app_dependencies,
	vala_args: vala_platform_args,
	link_args: platform_link_args,
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
