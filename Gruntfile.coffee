# Build configurations.
module.exports = (grunt) ->

	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-contrib-watch'

	grunt.initConfig
		connect:
			app:
				options:
					base: './src/'
					middleware: require './server/middleware'
					port: 5000
		watch:
			options:
				livereload: false
		karma:
			unit:
				options:
					autoWatch: true
					colors: true
					configFile: './test/karma.conf.js'
					keepalive: true
					port: 8081
					runnerPort: 9100
			travis:
				options:
					colors: true
					configFile: './test/karma.conf.js'
					runnerPort: 9100
					singleRun: true


		# Starts a web server
		# Enter the following command at the command line to execute this task:
		# grunt server
		grunt.registerTask 'server', [
			'connect'
			'watch'
		]

	grunt.registerTask 'default', ['server']

	grunt.registerTask 'test', [
		'karma:unit'
	]

	grunt.registerTask 'travis', [
		'karma:travis'
	]