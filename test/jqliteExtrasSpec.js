debugger
describe('\njqLite: testing against jQuery\n', function () {
	'use strict';

	var sandbox = angular.element('<div/>');

	var extras = undefined;

	beforeEach(module('ui.scroll.jqlite'));
	beforeEach(function(){
		angular.element(document).find('body').append(sandbox = angular.element('<div></div>'));
		inject(function(jqLiteExtras) {
			extras = function(){};
			jqLiteExtras.registerFor(extras)
		})
	});

	afterEach(function() {sandbox.remove();});

	describe('height() getter and outerHeight() getter\n', function () {

		angular.forEach(
			[
				'<div>some text</div>',
				'<div style="height:30em">some text (height in em)</div>',
				'<div style="height:30px">some text height in px</div>',
				'<div style="border-width: 3px; border-style: solid; border-color: red">some text w border</div>',
				'<div style="padding: 3px">some text w padding</div>',
				'<div style="margin: 3px">some text w margin</div>',
				'<div style="margin: 3em">some text w margin</div>'
			], function(element) {

				function createElement(element) {
					var result = angular.element(element);
					sandbox.append(result);
					return result;
				}

				function validateHeight(element) {
					expect(extras.prototype.height.call(element)).toBe(element.height())
				}

				function validateOuterHeight(element, options) {
					if (options)
						expect(extras.prototype.outerHeight.call(element, options)).toBe(element.outerHeight(options))
					else
						expect(extras.prototype.outerHeight.call(element)).toBe(element.outerHeight())
				}
				it('height() for ' + element, function() {
						validateHeight(createElement(element))
					}
				)

				it('outerHeight() for ' + element, function() {
						validateOuterHeight(createElement(element))
					}
				)

				it('outerHeight(true) for ' + element, function() {
						validateOuterHeight(createElement(element), true)
					}
				)
			}

		)
	})


	})