local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")

-- The Lune publisher replaces this placeholder with a quoted JSON string before submitting the task.
local config = HttpService:JSONDecode(__PLUGIN_UPLOAD_CONFIG_JSON__)
local args: any = ...
local plugin = SerializationService:DeserializeInstancesAsync(args.BinaryInput)[1]

print(`Publishing plugin {config.assetId}: {config.name}`)
local result, versionOrError = AssetService:CreateAssetVersionAsync(plugin, Enum.AssetType.Plugin, config.assetId, {
	Name = config.name,
	Description = config.description,
	CreatorId = config.creatorId,
	CreatorType = Enum.AssetCreatorType:FromName(config.creatorType),
})

if result ~= Enum.CreateAssetResult.Success then
	error(`Plugin publish failed: {result.Name} - {versionOrError}`)
end

print(`Plugin uploaded successfully. New version is {versionOrError}.`)
