# Build configurations.
module.exports = (grunt) ->

	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-contrib-jshint'

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

		jshint:
			src:
				files:
					src: ['./build/**/*.js']
				options: jshintrc: '.jshintrc'

		# Compile CoffeeScript (.coffee) files to JavaScript (.js).
		coffee:
			build:
				files: [
					cwd: './src'
					src: 'scripts/**/*.coffee'
					dest: './build/'
					expand: true
					ext: '.js'
				]
				options:
					bare: true
					#sourceMap: true


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

	grunt.registerTask 'build', ['coffee:build', 'jshint']

	grunt.registerTask 'travis', [
		'karma:travis'
	]