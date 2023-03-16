import nim_openai/[client]

# let
#     env = loadEnvFile(".env")
#     openAi = newOpenAiClient(apiKey = env.get("API_KEY1"))

# openAi.API_KEY = 

# openAi.client = newHttpClient()

# var it = newCompletionParams("Hello")

# echo openAi.createModeration(newModerationParams("J")).repr

# openAi.isAsync = true

# openAi.client = newAsyncHttpClient()

# echo openAi[]
# echo it

var it: array[4, int]

# it = [2]
echo it