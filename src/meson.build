app_sources = files(
	'main.vala',
	'application.vala',
) + configure_file(
	input: 'build.vala.in',
	output: 'build.vala',
	configuration: config
) + app_resources

subdir('ui')

app_dependencies = [
	dependency('libadwaita-1'),
]

executable(
	basename,
	sources: app_sources,
	dependencies: app_dependencies,
	install: true
)
