#### OpenAi Nim Client

##### How To Use

[1] Load your environmental variables from your .env file

```nim
import openai

let 
    pathToEnvFile = ".env"
    env = loadEnv(pathToEnvFile)

```

[2] Import your api_keys from your environmental variables 

```nim
let api_key = env.get("API_KEY")
```

[3] Initialise a new openAi Client

```nim

let 
    openai = newOpenAiClient(api_key = api_key)

### you can also decide to have an asynchronous client by doing:

    # import asyncdispatch
    # let openai = newAsyncOpenAiClient(api_key = api_key)

```

[4] Prepare your request parameters with Json

```nim
import json

let imageEditParameters = %* {
        "image": "pic.png", 
        "mask": "pic.png", 
        "prompt": "An Astronaut Suit For   Master Yoda", 
        "n": 2, 
        "size": "512x512"
    }

#this library will automatically check if your request parameters are in agreement with what openAi requires, and will quit with helpful error messages if there is a disparity.

```

[5] Pass the parameters as the body to the openai function you wish to call 

```nim

let openaiResponse = openai.createImageEdit(imageEditParameters)

## if your client is async, you will need to await the response like so:

#   let asyncOpenaiResponse = await openai.createImageEdit(imageEditParameters)

```
[6] Use the reponse from openai to build cool stuffs 

```nim
echo openaiResponse.body()
```