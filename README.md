### OpenAI api client for Nim Lang
This is a simple implementation of a Nim lang client for the openai api spec (as found in the spec.yaml file above). This client has support for asynchronous requests and parameters are passed as json.


### Installation

```console
nimble install openaiclient
```

### Usage

[1] Create a file to hold your apikeys and other environmental variables and construct a new openai client 

```nim
import openai

let 
    env = loadEnv(".env")
    apiKey = env.get("API_KEY")
    openai = newOpenAiClient(apikey = apikey)
## if you need to use an asynchronous client then:
##import asyncdispatch
##let openai = newAsyncOpenAiClient(apikey = apikey)

```

[2] Setup your parameters as json and pass them to the [openai functions](https://platform.openai.com/docs/api-reference) you wish to call

```nim
import json

let imageEditRequestParams = %*{"image": "pic.png", "mask": "pic.png", "prompt": "A Nice Tesla For Asiwaju",   "n": 2, "size": "512x512"}

let imageEditResponse = openai.createImageEdit(imageEditRequestParams)

#use the response for whatever cool stuff you are trying to do

echo imageEditResponse

```

### Contributions
Contributions to the OpenAI Nim client are welcome. If you find a bug or have a suggestion for a new feature, please open an issue on the GitHub repository. If you would like to contribute code, please fork the repository and submit a pull request.