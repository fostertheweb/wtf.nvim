local helpers = require("tests.wtf.helpers")
local mock = require("luassert.mock")
local spy = require("luassert.spy")
local stub = require("luassert.stub")
local wtf = require("wtf")

describe("Explain", function()
  local client_mock
  local popup_mock

  before_each(function()
    helpers.disable_notifications()

    helpers.create_lines({
      "function greet(name)",
      "  if name then",
      "    print('Hello, ' .. name)",
      "  end",
      "end",
      "",
    })

    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    -- Mock dependencies
    client_mock = stub(package.loaded, "wtf.ai.client")
    client_mock.returns("This is a test response")
    popup_mock = mock(require("wtf.ui.popup"), true)

    wtf.setup()
  end)

  after_each(function()
    client_mock:revert()
    mock.revert(popup_mock)
  end)

  it("explains the current line with no diagnostics", function(done)
    local popup_spy = spy.on(popup_mock, "show")
    wtf.explain()
    vim.defer_fn(function()
      assert.spy(client_mock).was.called()
      assert.spy(popup_spy).was.called_with("This is a test response")
      done()
    end, 100)
  end)

  it("explains a visual range", function(done)
    local popup_spy = spy.on(popup_mock, "show")
    wtf.explain({ line1 = 2, line2 = 3 })
    vim.defer_fn(function()
      assert.spy(client_mock).was.called()
      local payload = client_mock.calls[1].vals[2]
      assert.truthy(string.find(payload, "if name then"))
      assert.truthy(string.find(payload, "print"))
      assert.spy(popup_spy).was.called_with("This is a test response")
      done()
    end, 100)
  end)

  it("includes logical block context in the payload", function(done)
    wtf.explain()
    vim.defer_fn(function()
      assert.spy(client_mock).was.called()
      local payload = client_mock.calls[1].vals[2]
      assert.truthy(string.find(payload, "if name then"))
      assert.truthy(string.find(payload, "selected code"))
      assert.truthy(string.find(payload, "surrounding logical block"))
      done()
    end, 100)
  end)

  it("includes additional instructions when configured", function(done)
    wtf.setup({
      additional_instructions = "Start the reply with 'OH HAI THERE'",
    })

    wtf.explain()
    vim.defer_fn(function()
      assert.spy(client_mock).was.called()
      local payload = client_mock.calls[1].vals[2]
      assert.truthy(string.find(payload, "OH HAI THERE"))
      done()
    end, 100)
  end)

  it("returns a warning when invoked on an empty line", function()
    vim.api.nvim_win_set_cursor(0, { 6, 0 })
    local result = wtf.explain()
    assert.are.equal("No code selected", result)
  end)
end)
