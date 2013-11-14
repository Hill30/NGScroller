/*global describe, beforeEach, module, inject, it, spyOn, expect, $ */
describe('uiScroll', function () {
    'use strict';

    angular.module('ui.scroll.test', [])
        .factory('myEmptyDatasource', [
            '$log', '$timeout', '$rootScope', function(console, $timeout, $rootScope) {
                var current, get, loading, revision;
                get = function(index, count, success) {
                    success([]);
                };

                return {
                    get: get
                };
            }
        ])

        .factory('myOnePageDatasource', [
            '$log', '$timeout', '$rootScope', function(console, $timeout, $rootScope) {
                var current, get, loading, revision;
                get = function(index, count, success) {
                    if (index === 1) {
                        success(['one', 'two', 'three']);
					} else {
                        success([]);
					}
                };

                return {
                    get: get
                };
            }
        ])

        .factory('myMultipageDatasource', [
            '$log', '$timeout', '$rootScope', function(console, $timeout, $rootScope) {
                var current, get, loading, revision;
                get = function(index, count, success) {
                    var result = [];
                    if (index > 0 && index <= 20) {
                        for (var i = index; i<index+count && i<=20; i++) {
                            result.push('item' + i);
						}
                    }
                    success(result);
                };

                return {
                    get: get
                };
            }
        ]);

    var sandbox = angular.element('<div/>');

    beforeEach(module('ui.scroll'));
    beforeEach(module('ui.scroll.test'));

	var runTest = function(html, runTest, cleanupTest) {
		inject(function($rootScope, $compile, $window, $timeout) {
				var scroller = angular.element(html);
				var scope = $rootScope.$new();
				var sandbox = angular.element('<div/>');
				angular.element(document).find('body').append(sandbox);
				sandbox.append(scroller);
				$compile(scroller)(scope);
				scope.$apply();
				$timeout.flush();

				runTest($window, sandbox);

				scroller.remove();
				scope.$destroy();

				if (cleanupTest) {
					cleanupTest($window, scope);
				}
			}
		)
	}

	describe('basic setup', function() {
			var html = '<div ng-scroll="item in myEmptyDatasource">{{$index}}: {{item}}</div>';

				it('should bind to window scroll and resize events and unbind upon scope destroy', function(){
				spyOn($.fn, 'bind').andCallThrough();
				spyOn($.fn, 'unbind').andCallThrough();
				runTest(html,
					function($window) {
						expect($.fn.bind.calls.length).toBe(2);
						expect($.fn.bind.calls[0].args[0]).toBe('resize');
						expect($.fn.bind.calls[0].object[0]).toBe($window);
						expect($.fn.bind.calls[1].args[0]).toBe('scroll');
						expect($.fn.bind.calls[1].object[0]).toBe($window);
						expect($._data($window, 'events')).toBeDefined();
					},
					function($window) {
						expect($.fn.unbind.calls.length).toBe(2);
						expect($.fn.unbind.calls[0].args[0]).toBe('resize');
						expect($.fn.unbind.calls[0].object[0]).toBe($window);
						expect($.fn.unbind.calls[1].args[0]).toBe('scroll');
						expect($.fn.unbind.calls[1].object[0]).toBe($window);
					}
				);
			});

			it('should create 2 divs of 0 height', function() {
				runTest(html,
					function($window, sandbox) {
						expect(sandbox.children().length).toBe(2);

						var topPadding = sandbox.children()[0];
						expect(topPadding.tagName.toLowerCase()).toBe('div');
						expect(angular.element(topPadding).css('height')).toBe('0px');

						var bottomPadding = sandbox.children()[1];
						expect(bottomPadding.tagName.toLowerCase()).toBe('div');
						expect(angular.element(bottomPadding).css('height')).toBe('0px');

					}
				);
			});

			it('should call get on the datasource 1 time ', function() {
				var spy;
				inject(function(myEmptyDatasource){
					spy = spyOn(myEmptyDatasource, 'get').andCallThrough();
				});
				runTest(html,
					function() {
						expect(spy.calls.length).toBe(2);
						expect(spy.calls[0].args[0]).toBe(1);
						expect(spy.calls[1].args[0]).toBe(-9);

					}
				);
			});
		}
	);

	describe('datasource with only 3 elements', function () {

		var html = '<div ng-scroll="item in myOnePageDatasource">{{$index}}: {{item}}</div>';

		it('should create 3 divs with data (+ 2 padding divs)', function() {
			runTest(html,
				function($window, sandbox) {
					expect(sandbox.children().length).toBe(5);

					var row1 = sandbox.children()[1];
					expect(row1.tagName.toLowerCase()).toBe('div');
					expect(row1.innerHTML).toBe('1: one');

					var row2 = sandbox.children()[2];
					expect(row2.tagName.toLowerCase()).toBe('div');
					expect(row2.innerHTML).toBe('2: two');

					var row3 = sandbox.children()[3];
					expect(row3.tagName.toLowerCase()).toBe('div');
					expect(row3.innerHTML).toBe('3: three');
				}
			);
		});

		it('should call get on the datasource 3 times ', function() {
			var spy;
			inject(function(myOnePageDatasource){
				spy = spyOn(myOnePageDatasource, 'get').andCallThrough();
			runTest(html,
				function() {
					expect(spy.calls.length).toBe(3);

					expect(spy.calls[0].args[0]).toBe(1);  // gets 3 rows
					expect(spy.calls[1].args[0]).toBe(4);  // gets eof
					expect(spy.calls[2].args[0]).toBe(-9); // gets bof
				});
			});

		});
	});

	describe('datasource with 20 elements default buffer size (10) - constrained viewport', function () {

		var html = '<div ng-scroll-viewport style="height:200px"><div style="height:40px" ng-scroll="item in myMultipageDatasource" buffer-size="3">{{$index}}: {{item}}</div></div>';

		it('should create 6 divs with data (+ 2 padding divs)', function() {
			runTest(html,
				function($window, sandbox) {
					var scroller = sandbox.children();
					expect(scroller.children().length).toBe(8);

					for (var i = 1; i< 7; i++) {
						var row = scroller.children()[i];
						expect(row.tagName.toLowerCase()).toBe('div');
						expect(row.innerHTML).toBe(i + ': item' + i);
					}

				}
			);
		});

		it('should call get on the datasource 3 times ', function() {
			var spy;
			inject(function(myMultipageDatasource){
				spy = spyOn(myMultipageDatasource, 'get').andCallThrough();
			});
			runTest(html,
				function($window, sandbox) {
					expect(spy.calls.length).toBe(3);

					expect(spy.calls[0].args[0]).toBe(1);
					expect(spy.calls[1].args[0]).toBe(4);
					expect(spy.calls[2].args[0]).toBe(-2);

				}
			);
		});

	});


    describe('datasource with 20 elements default buffer size (10) - unconstrained viewport', function () {

        return;

        var HTML = '<div ng-scroll="item in myMultipageDatasource">{{$index}}: {{item}}</div>';

        it('should create 20 divs with data (+ 2 padding divs)', inject(
            function ($rootScope, $compile) {
                var scroller = angular.element(HTML);
                sandbox.append(scroller);
                $compile(scroller)($rootScope);
                $rootScope.$apply();

                expect(sandbox.children().length).toBe(22);

                for (var i = 1; i< 21; i++) {
                    var row = sandbox.children()[i];
                    expect(row.tagName.toLowerCase()).toBe('div');
                    expect(row.innerHTML).toBe(i + ': item' + i);
                }

            }));

        it('should call get on the datasource 4 times ', inject(
            function ($rootScope, $compile, myMultipageDatasource) {

                var spy = spyOn(myMultipageDatasource, 'get').andCallThrough();
                var scroller = angular.element(HTML);
                sandbox.append(scroller);
                $compile(scroller)($rootScope);
                $rootScope.$apply();

                expect(spy.calls.length).toBe(4);

                expect(spy.calls[0].args[0]).toBe(1);
                expect(spy.calls[1].args[0]).toBe(11);
                expect(spy.calls[2].args[0]).toBe(21);
                expect(spy.calls[3].args[0]).toBe(-9);

            }));
    });

    describe('datasource with 20 elements buffer size 7 - unconstrained viewport', function () {

        return;

        var HTML = '<div ng-scroll="item in myMultipageDatasource" buffer-size="7">{{$index}}: {{item}}</div>';

        it('should create 20 divs with data (+ 2 padding divs)', inject(
            function ($rootScope, $compile) {
                var scroller = angular.element(HTML);
                sandbox.append(scroller);
                $compile(scroller)($rootScope);
                $rootScope.$apply();

                expect(sandbox.children().length).toBe(22);

                for (var i = 1; i< 21; i++) {
                    var row = sandbox.children()[i];
                    expect(row.tagName.toLowerCase()).toBe('div');
                    expect(row.innerHTML).toBe(i + ': item' + i);
                }

            }));

        it('should call get on the datasource 4 times ', inject(
            function ($rootScope, $compile, myMultipageDatasource) {

                var spy = spyOn(myMultipageDatasource, 'get').andCallThrough();
                var scroller = angular.element(HTML);
                sandbox.append(scroller);
                $compile(scroller)($rootScope);
                $rootScope.$apply();

                expect(spy.calls.length).toBe(5);

                expect(spy.calls[0].args[0]).toBe(1);
                expect(spy.calls[1].args[0]).toBe(8);
                expect(spy.calls[2].args[0]).toBe(15);
                expect(spy.calls[3].args[0]).toBe(21);
                expect(spy.calls[4].args[0]).toBe(-6);

            }));
    });


});