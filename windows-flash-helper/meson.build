windres = find_program('windres', required: true)

flash_helper_manifest = custom_target(
	'flash-helper-manifest',
	input: 'flash-helper.rc',
	output: 'flash-helper-manifest.o',
	command: [windres, '-I', meson.current_source_dir(), '@INPUT@', '@OUTPUT@'],
)

executable(
	'FlashHelper',
	sources: files(
		'main.vala',
		'flash-pipe.vala',
	) + [flash_helper_manifest],
	dependencies: [dependency('gio-2.0')],
	vala_args: [
		'--vapidir=' + meson.project_source_root() / 'vapi',
		'--pkg=win32-storage',
		'--define=WINDOWS',
	],
	link_args: ['-lsetupapi'],
	install: true
)
