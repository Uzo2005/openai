#[
  This Module implements an OpenAI REST API Client In Nim:
    openapi: 3.0.0
    info:
      title: OpenAI API
      description: APIs for sampling from and fine-tuning language models
      version: '1.2.0'

]#

import std/[tables, parsecfg, streams]

type
  Env* = object
    data: OrderedTableRef[string, string]
  EnvWrongFormatError* = object of CatchableError

func initEnv(): Env {.inline.} =
  ## Initializes an `Env`.
  Env(data: newOrderedTable[string, string]())

func get*(env: Env, key: string): string {.inline.} =
  ## Retrieves a value of `key` in `Env`.
  result = env.data[key]

proc loadEnvFile*(filename: string): Env =
  ##loads the env file
  result = initEnv()
  var f = newFileStream(filename, fmRead)

  if f != nil:
    var p: CfgParser
    open(p, f, filename)
    while true:
      var e = p.next
      case e.kind
        of cfgEof:
          break
        of cfgKeyValuePair:
          result.data[e.key] = e.value
        else:
          raise newException(EnvWrongFormatError, ".env files only support key-value pairs")
    f.close()
    p.close()

import std/[httpclient, asyncdispatch, json, strformat]


const
  OPENAI_API_URL* = "https://api.openai.com/v1"

type
  OpenAi_Api* = ref object
    API_KEY: string
    case isAsync: bool
      of true:
        asynchttpClient: AsyncHttpClient
      else:
        httpClient: HttpClient

proc defaultHeader(api_key: string): HttpHeaders =
  result = newHttpHeaders([("Authorization", fmt"Bearer {api_key}")])

proc newOpenAiClient*(api_key: string): OpenAi_Api =
  result = OpenAi_Api(API_KEY: api_key, isAsync: false,
      httpClient: newHttpClient(headers = defaultHeader(api_key)))

proc newAsyncOpenAiClient*(api_key: string): OpenAi_Api =
  result = OpenAi_Api(API_KEY: api_key, isAsync: true,
      asynchttpClient: newAsyncHttpClient(headers = defaultHeader(api_key)))

proc getSync(client: HttpClient; relativePath: string): Response =

  result = client.get(OPEN_AI_API_URL & relativePath)

proc getAsync(client: AsyncHttpClient; relativePath: string): Future[
    AsyncResponse] =

  result = client.get(OPEN_AI_API_URL & relativePath)


proc postSync(client: HttpClient; relativePath: string,
    requestBody: string = ""): Response =

  result = client.post(OPEN_AI_API_URL & relativePath, requestBody)


proc postAsync(client: AsyncHttpClient; relativePath: string,
    requestBody: string = ""): Future[AsyncResponse] =

  result = client.post(OPEN_AI_API_URL & relativePath, requestBody)

proc deleteSync(client: HttpClient; relativePath: string): Response =

  result = client.delete(OPEN_AI_API_URL & relativePath)

proc deleteAsync(client: AsyncHttpClient; relativePath: string): Future[
    AsyncResponse] =

  result = client.delete(OPEN_AI_API_URL & relativePath)


template makeRequestProc(procName, procType: untyped; requiredParams, optionalParams: seq[string]): untyped =
  proc `procName`(body: JsonNode): `procType` =
    var 
        temp = %*{}
        required = toHashSet(`requiredParams`)
        optional = toHashSet(`optionalParams`)
        allPossibleParams = required + optional
    
    for key in body.keys:
        if key in allPossibleParams:
            allPossibleParams.excl(key)
            temp[key] = body[key]
        else:
            echo key, " is not a valid key in the ", `procType`," schema"
            quit(1)
    
    let omittedRequiredParams = allPossibleParams - optional

    if omittedRequiredParams.len > 0:
        echo omittedRequiredParams, " is a required Parameter in the ", `procType`, " schema but has not been provided"
        quit(1)

    result = temp












proc createCompletion*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates a completion for the provided prompt and parameters
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/completions", $body)
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/completions", $(%body))


proc createChatCompletion*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates a completion for the chat message
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.httpClient, "/chat/completions", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/chat/completions", $(%body))

proc createEdit*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates a new edit for the provided input, instruction, and parameters.
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.httpClient, "/edits", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.asynchttpClient, "/edits", $(%body))

proc createImage*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates an image given a prompt.
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.httpClient, "/images/generations", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.asynchttpClient, "/images/generations", $(%body))

proc createImageEdit*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates an edited or extended image given an original image and a prompt.
  let
    image = readFile(body.imageFilePath)
    mask = readFile(body.maskFilePath)
    newBody = %*{
                  "image": %image,
                  "mask": %mask,
                  "prompt": %body.prompt,
                  "n": %body.n,
                  "size": %body.size
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "multipart/form-data"
    result = postAsync(apiConfig.asynchttpClient, "/images/edits", $newBody)
  else:
    apiConfig.httpClient.headers["content"] = "multipart/form-data"
    result = postSync(apiConfig.httpClient, "/images/edits", $newBody)

proc createImageVariation*(apiConfig: OpenAI_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates a variation of a given image.
  let
    image = readFile(body.imageFilePath)
    newBody = %*{
                  "image": %image,
                  "n": %body.n,
                  "size": %body.size
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "multipart/form-data"
    result = postAsync(apiConfig.asynchttpClient, "/images/variations", $newBody)
  else:
    apiConfig.httpClient.headers["content"] = "multipart/form-data"
    result = postSync(apiConfig.httpClient, "/images/variations", $newBody)

proc createEmbedding*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Creates an embedding vector representing the input text.
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/embeddings", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/embeddings", $(%body))

proc createTranscription*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Transcribes audio into the input language.
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "multipart/form-data"
    result = postAsync(apiConfig.asynchttpClient, "/audio/transcriptions", $newBody)
  else:
    apiConfig.httpClient.headers["content"] = "multipart/form-data"
    result = postSync(apiConfig.httpClient, "/audio/transcriptions", $newBody)

proc createTranslation*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Translates audio into into English.
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "multipart/form-data"
    result = postAsync(apiConfig.asynchttpClient, "/audio/translations", $newBody)
  else:
    apiConfig.httpClient.headers["content"] = "multipart/form-data"
    result = postSync(apiConfig.httpClient, "/audio/translations", $newBody)

proc createSearch*(apiConfig: OpenAi_Api; engineId: string,
    body: JsonNode): Response | Future[AsyncResponse] =
  ## The search endpoint computes similarity scores between provided query and documents. Documents can be passed directly to the API if there are no more than 200 of them.
  ##
  ## To go beyond the 200 document limit, documents can be processed offline and then used for efficient retrieval at query time.
  ##  When `file` is set, the search endpoint searches over all the documents in the given file and returns up to the `max_rerank` number of documents.
  ##  These documents will be returned along with their search scores.
  ##
  ##  The similarity score is a positive score that usually ranges from 0 to 300 (but can sometimes go higher), where a score above 200 usually means the document is semantically similar to the query.
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, fmt"/engines/{engineId}/search",$(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, fmt"/engines/{engineId}/search", $(%body))

proc listFiles*(apiConfig: OpenAi_Api): Response | Future[AsyncResponse] =
  ## Returns a list of files that belong to the user's organization.
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = getAsync(apiConfig.asynchttpclient, "/files")
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = getSync(apiConfig.httpClient, "/files")

proc createFile*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Upload a file that contains document(s) to be used across various endpoints/features.
  ##  Currently, the size of all the files uploaded by one organization can be up to 1 GB.
  ##  Please contact us if you need to increase the storage limit.
  let
    file = readFile(body.filePath)
    newBody = %*{
                    "file": %file,
                    "purpose": %body.purpose
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "multipart/form-data"
    result = postAsync(apiConfig.asynchttpClient, "/file", $(%newBody))
  else:
    apiConfig.httpClient.headers["content"] = "multipart/form-data"
    result = postSync(apiConfig.httpClient, "/file", $(%newBody))


proc deleteFile*(apiConfig: OpenAi_Api; fileId: string): Response | Future[AsyncResponse] =
  ## Delete a file.
  if apiConfig.isAsync:
    result = deleteAsync(apiConfig.asynchttpClient, fmt"/files/{fileId}")
  else:
    result = deleteSync(apiConfig.httpClient, fmt"/files/{fileId}")

proc retrieveFile*(apiConfig: OpenAi_Api; fileId: string): Response | Future[AsyncResponse] =
  ## Returns information about a specific file.
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, fmt"/file/{fileId}")
  else:
    result = getSync(apiConfig.httpClient, fmt"/file/{fileId}")

proc downloadFile*(apiConfig: OpenAi_Api; fileId: string,
    saveToFileName = fileId): Future[void] =
  ## Returns the contents of the specified file
  let client = newAsyncHttpClient()
  result = httpclient.downloadFile(client, fmt"/file/{fileId}", saveToFileName)

proc createAnswer*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ## Answers the specified question using the provided documents and examples.
  ## The endpoint first [searches](/docs/api-reference/searches) over provided documents or files to find relevant context.
  ##  The relevant context is combined with the provided examples and question to create the prompt for [completion](/docs/api-reference/completions).
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/answers", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/answers", $(%body))

proc createClassifications*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Classifies the specified `query` using provided examples.
  ##
  ## The endpoint first [searches](/docs/api-reference/searches) over the labeled examples
  ## to select the ones most relevant for the particular query. Then, the relevant examples
  ## are combined with the query to construct a prompt to produce the final label via the
  ## [completions](/docs/api-reference/completions) endpoint.
  ##
  ## Labeled examples can be provided via an uploaded `file`, or explicitly listed in the
  ## request using the `examples` parameter for quick tests and small scale use cases.
  
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/classifications", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/classifications", $(%body))

proc createFineTune*(apiConfig: OpenAi_Api; body: JsonNode): Response | Future[AsyncResponse] =
  ##  Creates a job that fine-tunes a specified model from a given dataset.
  ##
  ##  Response includes details of the enqueued job including job status and the name of the fine-tuned models once complete.
  ##
  ##  [Learn more about Fine-tuning](/docs/guides/fine-tuning)

  let
    training_file = readFile(body.training_filePath)
    newBody = %*{
                  "training_file": %training_file
      }
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/fine-tunes", $(%newBody))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/fine-tunes", $(%newBody))

proc listFineTunes*(apiConfig: OpenAi_Api): Response | Future[AsyncResponse] =
  ## List your organization's fine-tuning jobs
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, "/fine-tunes")
  else:
    result = getSync(apiConfig.httpClient, "/fine-tunes")

proc retrieveFineTune*(apiConfig: OpenAi_Api; fineTuneId: string): Response | Future[AsyncResponse] =
  ## Gets info about the fine-tune job.
  ##
  ## [Learn more about Fine-tuning](/docs/guides/fine-tuning)
  
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, fmt"/fine-tunes/{fineTuneId}")
  else:
    result = getSync(apiConfig.httpClient, fmt"/fine-tunes/{fineTuneId}")

proc cancelFineTune*(apiConfig: OpenAi_Api; fineTuneId: string): Response | Future[AsyncResponse] =
  ## Immediately cancel a fine-tune job.
  if apiConfig.isAsync:
    result = postAsync(apiConfig.asynchttpClient, fmt"/fines-tunes/{fineTuneId}/cancel")
  else:
    result = postSync(apiConfig.httpClient, fmt"/fines-tunes/{fineTuneId}/cancel")

proc listFineTuneEvents*(apiConfig: OpenAi_Api; fineTuneId: string): Response | Future[AsyncResponse] =
  ## Get fine-grained status updates for a fine-tune job.
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, fmt"/fines-tunes/{fineTuneId}/events")
  else:
    result = getSync(apiConfig.httpClient, fmt"/fines-tunes/{fineTuneId}/events")

proc listModels*(apiConfig: OpenAi_Api): Response | Future[AsyncResponse] =
  ## Lists the currently available models, and provides basic information about each one such as the owner and availability.
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, "/models")
  else:
    result = getSync(apiConfig.httpClient, "/models")

proc retrieveModel*(apiConfig: OpenAi_Api; model: string): Response | Future[AsyncResponse] =
  ## Retrieves a model instance, providing basic information about the model such as the owner and permissioning.
  if apiConfig.isAsync:
    result = getAsync(apiConfig.asynchttpclient, fmt"/models/{model}")
  else:
    result = getSync(apiConfig.httpClient, fmt"/models/{model}")

proc deleteModel*(apiConfig: OpenAi_Api; model: string): Response | Future[AsyncResponse] =
  ## Delete a fine-tuned model. You must have the Owner role in your organization.
  if apiConfig.isAsync:
    result = deleteAsync(apiConfig.asynchttpClient, fmt"/models/{model}")
  else:
    result = deleteSync(apiConfig.httpClient, fmt"/models/{model}")

proc createModeration*(apiConfig: OpenAi_Api;
    body: JsonNode): Response | Future[AsyncResponse] =
  ## Classifies if text violates OpenAI's Content Policy
  if apiConfig.isAsync:
    apiConfig.asynchttpClient.headers["content"] = "application/json"
    result = postAsync(apiConfig.asynchttpClient, "/moderations", $(%body))
  else:
    apiConfig.httpClient.headers["content"] = "application/json"
    result = postSync(apiConfig.httpClient, "/moderations", $(%body))
