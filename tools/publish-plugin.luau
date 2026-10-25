local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local execute = require("./opencloud-execute")

local pluginPath = assert(process.args[1], "Usage: lune run tools/publish-plugin.luau <plugin.rbxm>")
local config = serde.decode("json", fs.readFile("tools/plugin-upload.json"))
for _, field in { "assetId", "universeId", "placeId", "creatorId" } do
	assert(type(config[field]) == "number" and config[field] > 0, `Invalid {field} in tools/plugin-upload.json`)
end
assert(config.creatorType == "User", "The plugin and task place must be owned by the configured user")
assert(type(config.name) == "string" and config.name ~= "", "Missing plugin name")
assert(type(config.description) == "string", "Missing plugin description")
assert(process.env.RBX_API_KEY and process.env.RBX_API_KEY ~= "", "Set RBX_API_KEY in the environment")

-- Substitute a quoted JSON literal into the task source; metadata is never built into the plugin.
local source = fs.readFile("tools/publish-plugin-task.luau")
local replacements
source, replacements = source:gsub("__PLUGIN_UPLOAD_CONFIG_JSON__", function()
	return string.format("%q", serde.encode("json", config))
end)
assert(replacements == 1, "Expected exactly one upload configuration placeholder")

print(`Creating task to publish plugin {config.assetId}`)
local uploadTask = execute.create_task_latest(
	tostring(config.universeId),
	tostring(config.placeId),
	source,
	300,
	false,
	fs.readFile(pluginPath)
)
print(`Task: {uploadTask.path}`)

-- The pinned helper's await_finish treats QUEUED as a terminal state, so poll both active states here.
local deadline = os.clock() + 360
local delay = 1
local state = execute.check_status(uploadTask)
while (state == "QUEUED" or state == "PROCESSING") and os.clock() < deadline do
	task.wait(delay)
	delay = math.min(delay * 2, 16)
	state = execute.check_status(uploadTask)
end

local logsOk, logs = pcall(execute.get_structured_logs, uploadTask)
if logsOk then
	for _, entry in logs do
		print(serde.encode("json", entry))
	end
else
	warn(`Could not fetch task logs: {logs}`)
end

if state ~= "COMPLETE" then
	local failure = if state == "FAILED" then execute.get_error(uploadTask) else nil
	if failure then
		warn(`Plugin publish failed: {failure.code}: {failure.message}`)
	else
		warn(`Plugin publish did not complete; last task state: {state}`)
	end
	process.exit(1)
end
assert(logsOk, "Plugin task completed, but its logs could not be retrieved")
print("Plugin publish task completed successfully")
