app_sources = files(
	'main.vala',
	'application.vala',

	'ui' / 'main-window.vala',
	'ui' / 'home-page.vala',
	'ui' / 'write-page.vala',
	'ui' / 'devices-page.vala',
	'ui' / 'download-page.vala',
	'ui' / 'device-card.vala',

	'repository' / 'osinfo-repository.vala',

	'service' / 'osinfo-service.vala',

) + configure_file(
	input: 'build.vala.in',
	output: 'build.vala',
	configuration: config
) + app_resources

app_dependencies = [
	dependency('libadwaita-1'),
	dependency('libdex-1'),
	dependency('libosinfo-1.0'),
	dependency('gee-0.8'),
]

executable(
	basename,
	sources: app_sources,
	dependencies: app_dependencies,
	vala_args: ['--pkg=posix'],
	install: true
)
