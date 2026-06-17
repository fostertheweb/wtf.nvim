local get_env_var = require("wtf.util.get_env_var")

---@type Wtf.Adapter
return {
  name = "opencode",
  formatted_name = "OpenCode",
  url = "https://opencode.ai/zen/go/v1/chat/completions",
  model_id = "opencode-go/qwen3.7-plus",
  headers = {
    ["Content-Type"] = "application/json",
    Authorization = "Bearer ${api_key}",
  },
  api_key = function()
    return get_env_var("OPENCODE_API_KEY")
  end,
  format_request = function(data)
    return {
      model = data.model,
      temperature = data.temperature,
      messages = {
        {
          role = "system",
          content = data.system,
        },
        {
          role = "user",
          content = data.message,
        },
      },
    }
  end,
  format_response = function(response)
    return response.choices[1].message.content
  end,
  format_error = function(response)
    return response.error.message
  end,
}
