# Build configurations.
module.exports = (grunt) ->

	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-contrib-jshint'
	grunt.loadNpmTasks 'grunt-contrib-concat'

	grunt.initConfig
		connect:
			app:
				options:
					base: './src/'
					middleware: require './server/middleware'
					port: 5001
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

		# transpile CoffeeScript (.coffee) files to JavaScript (.js).
		coffee:
			build:
				files: [
					cwd: './src'
					src: 'scripts/**/*.coffee'
					dest: './temp/'
					expand: true
					ext: '.js'
				]
				options:
					bare: true
					#sourceMap: true

		#prepend 'use strict' to the files
		concat:
		#usestrict:
			options:
				banner: "'use strict';\n"
			dynamic_mappings:
				files: [{
								expand: true
								cwd: './temp'
								src: ['**/*.js']
								dest: 'build/'
								ext: '.js'
								}]

		# run the linter
		jshint:
			src:
				files:
					src: ['./build/**/*.js']
				options: jshintrc: '.jshintrc'

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

	grunt.registerTask 'build', ['karma:travis', 'coffee:build', 'concat', 'jshint']

	grunt.registerTask 'travis', [
		'karma:travis'
	]