app_sources = files(
	'main.vala',
	'application.vala',
	'osinfo-loader.vala',
	'os-filter.vala'
) + configure_file(
	input: 'build.vala.in',
	output: 'build.vala',
	configuration: config
) + app_resources

subdir('ui')

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
	install: true
)
