/*global module*/

module.exports = function (grunt) {
    'use strict';

    grunt.initConfig({
        pkg: '<json:package.json>',

        // delete the public folder
        delete: {
            public: {
                src: '<%= pkg.public %>'
            }
        },

        // lint CoffeeScript
        coffeeLint: {
            scripts: {
                src: '<%= pkg.src %>scripts/**/*.coffee',
                indentation: {
                    value: 1,
                    level: 'error'
                },
                max_line_length: {
                    level: 'ignore'
                },
                no_tabs: {
                    level: 'ignore'
                }
            }
        },

        // compile CoffeeScript to JavaScript
        coffee: {
            public: {
                src: '<%= pkg.src %>scripts/**/*.coffee',
                dest: '<%= pkg.public %>scripts/',
                bare: true
            }
        },

        copy: {
            libs: {
                src: '<%= pkg.src %>scripts/libs/**/*.js',
                dest: '<%= pkg.public %>scripts/libs/'
            },
            images: {
                src: '<%= pkg.src %>images/',
                dest: '<%= pkg.public %>images/'
            },
            fonts: {
                src: '<%= pkg.src %>fonts/',
                dest: '<%= pkg.public %>fonts/'
            },
            flash: {
                src: '<%= pkg.src %>flash/',
                dest: '<%= pkg.public %>flash/'
            },
            styles: {
                src: '<%= pkg.src %>styles/**/*.css',
                dest: '<%= pkg.public %>styles/'
            },
            html: {
                src: '<%= pkg.src %>/**/*.html',
                dest: '<%= pkg.public %>/'
            },
            misc: {
                src: ['<%= pkg.src %>/favicon.ico', '<%= pkg.src %>/robots.txt', '<%= pkg.src %>/*.html'],
                dest: '<%= pkg.public %>'
            }
        },

        lint: {
            scripts: ['<%= pkg.src %>!(libs)**/*.js']
        },

        jshint: {
            options: {
                // CoffeeScript uses null for default parameter values
                eqnull: true
            }
        },

        // compile Less to CSS
        less: {
            public: {
                src: '<%= pkg.src %>styles/**/*.less',
                dest: '<%= pkg.public %>styles/styles.css'
            }
        },

        // compile templates
        template: {
            directives: {
                src: '<%= pkg.src %>/scripts/directives/templates/**/*.template',
                dest: '<%= pkg.public %>/scripts/directives/templates/'
//                ext: 'html'
            },
            dev: {
                src: '<%= pkg.src %>**/*.template',
                dest: '<%= pkg.public %>',
                environment: 'dev',
                indent_size: 1,
                indent_char: '\t',
                max_char: 10000
            },
            prod: {
                src: '<config:template.dev.src>',
                dest: '<config:template.dev.dest>',
                ext: '<config:template.dev.ext>',
                environment: 'prod'
            }
        },

        // optimizes files managed by RequireJS
        requirejs: {
            scripts: {
                baseUrl: './public/scripts/',
                findNestedDependencies: true,
                include: 'requireLib',
                logLevel: 0,
                mainConfigFile: './public/scripts/main.js',
                name: 'main',
                optimize: 'uglify',
                out: './public/scripts/scripts.min.js',
                paths: {
                    requireLib: 'libs/require'
                },
                preserveLicenseComments: false,
                uglify: {
                    no_mangle: true
                }
            },
            styles: {
                baseUrl: './public/styles/',
                cssIn: './public/styles/styles.css',
                logLevel: 0,
                optimizeCss: 'standard',
                out: './public/styles/styles.min.css'
            }
        },

        watch: {
            coffee: {
                files: '<%= pkg.src %>scripts/**/*.coffee',
                tasks: 'coffeeLint coffee lint'
            },
            less: {
                files: '<%= pkg.src %>styles/**/*.less',
                tasks: 'less'
            },
            css: {
                files: '<%= pkg.src %>styles/**/*.css',
                tasks: 'copy'
            },
            template: {
                files: '<config:template.dev.src>',
                tasks: 'template:dev'
            },
            copy_html: {
                files: ['' +
                    '<%= pkg.src %>/**/*.html',
                    '<%= pkg.src %>images/**/'
                ],
                tasks: 'copy'
            }
        },

        server: {
            app: {
                src: './server.coffee',
                port: 3005,
                watch: './server/routes.coffee'
            }
        }
    });

    grunt.loadNpmTasks('grunt-less');
    grunt.loadNpmTasks('grunt-hustler');
    grunt.registerTask('core', 'delete coffeeLint coffee copy lint less');
    grunt.registerTask('bootstrap', 'core template:dev');
    grunt.registerTask('default', 'bootstrap');
    grunt.registerTask('dev', 'bootstrap watch');
    grunt.registerTask('prod', 'core template:directives requirejs template:prod');
};
