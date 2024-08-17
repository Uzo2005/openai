import openaiClient
import httpclient, json

template Json(body: untyped): untyped =
    `%*`(body)

let
    env = loadEnvFile(".env")
    api_key = env.get("API_KEY")
    openai = newOpenAiClient(api_key = api_key)

let baz = Json {
    "image": "pic.png",
    "mask": "pic.png",
    "prompt": "A Nice Tesla For Asiwaju",
    "n": 2,
    "size": "512x512",
}

let foo = openai.createImageEdit(baz)
echo foo.body()

# import nim_openai/[client]
# import asyncdispatch

# let
#     env = loadEnvFile(".env")
#     api_key = env.get("API_KEY")
#     openai = newAsyncOpenAiClient(api_key = api_key)

# let foo = await openai.listmodels()

# echo foo
