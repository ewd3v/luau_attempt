_G.RUNTIME = "lune"

local task = require("@lune/task")

local attempt = require("./src")
local tiniest = require("./lune_packages/tiniest").for_runtime.configure({})

local function test_suite()
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	describe("attempt", function()
		test("runs functions", function()
			local ran = false
			attempt(nil, nil, function()
				ran = true
			end)

			expect(ran).is_true()
		end)

		test("does retry", function()
			local attempts, ran = 0, false
			attempt(2, nil, function()
				attempts += 1
				if attempts < 2 then
					error("")
				end

				ran = true
			end)

			expect(attempts).is(2)
			expect(ran).is_true()
		end)

		test("stops retrying after limit", function()
			local attempts, ran = 0, false
			attempt(1, nil, function()
				attempts += 1
				if attempts < 2 then
					error("")
				end

				ran = true
			end)

			expect(attempts).is(1)
			expect(ran).is(false)
		end)

		test("has delay on retry", function()
			local attempts, ran = 0, false
			task.spawn(getmetatable(attempt).__call, attempt, 3, 0.1, function()
				attempts += 1
				if attempts < 3 then
					error("")
				end

				ran = true
			end)

			task.wait(0.05)

			expect(attempts).is(1)
			expect(ran).is(false)

			task.wait(0.1)

			expect(attempts).is(2)
			expect(ran).is(false)

			task.wait(0.1)

			expect(attempts).is(3)
			expect(ran).is_true()
		end)

		describe("forever", function()
			test("runs functions", function()
				local ran = false
				attempt.forever(nil, function()
					ran = true
				end)

				expect(ran).is_true()
			end)

			test("does retry", function()
				local attempts, ran = 0, false
				attempt.forever(nil, function()
					attempts += 1
					if attempts < 2 then
						error("")
					end

					ran = true
				end)

				expect(attempts).is(2)
				expect(ran).is_true()
			end)
		end)

		describe("exponentially", function()
			test("runs functions", function()
				local ran = false
				attempt.exponentially(nil, function()
					ran = true
				end)

				expect(ran).is_true()
			end)

			test("does retry", function()
				local attempts, ran = 0, false
				attempt.exponentially(2, function()
					attempts += 1
					if attempts < 2 then
						error("")
					end

					ran = true
				end)

				expect(attempts).is(2)
				expect(ran).is_true()
			end)

			test("stops retrying after limit", function()
				local attempts, ran = 0, false
				attempt.exponentially(1, function()
					attempts += 1
					if attempts < 2 then
						error("")
					end

					ran = true
				end)

				expect(attempts).is(1)
				expect(ran).is(false)
			end)

			test("has correct delay on retry", function()
				local attempts, ran = 0, false
				task.spawn(attempt.exponentially, 3, function()
					attempts += 1
					if attempts < 3 then
						error("")
					end

					ran = true
				end)

				task.wait(0.9)

				expect(attempts).is(1)
				expect(ran).is(false)

				task.wait(2)

				expect(attempts).is(2)
				expect(ran).is(false)

				task.wait(0.5)

				expect(attempts).is(3)
				expect(ran).is_true()
			end)
		end)
	end)
end

local tests = tiniest.collect_tests(test_suite)
tiniest.run_tests(tests, {})
