#[
  This Module implements an OpenAI REST API Client In Nim:
    openapi: 3.0.0
    info:
      title: OpenAI API
      description: APIs for sampling from and fine-tuning language models
      version: '1.2.0'
]#

#TODO: Make 1024x1024 to escape properly, then impplement multipart data for all who needs it!

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

import std/[httpclient, asyncdispatch, json, strformat, sets]


const
  OpenAI_BASEURL* = "https://api.openai.com/v1"

type
  OpenAi_Client* = ref object
    API_KEY: string
    organization: string
    client: HttpClient
  Async_OpenAi_Client = ref object
    API_KEY: string
    organization: string
    client: AsyncHttpClient

proc defaultHeader(api_key, organization: string): HttpHeaders =
  if organization != "": 
    result = newHttpHeaders([("Authorization", fmt"Bearer {api_key}"), ("OpenAI_Organization", organization)])
  else:
    result = newHttpHeaders([("Authorization", fmt"Bearer {api_key}")])

proc newOpenAiClient*(api_key: string, organization = ""): OpenAi_Client =
  result = OpenAi_Client(API_KEY: api_key,
      client: newHttpClient(headers = defaultHeader(api_key, organization)))

proc newAsyncOpenAiClient*(api_key: string, organization = ""): Async_OpenAi_Client =
  result = Async_OpenAi_Client(API_KEY: api_key,
      client: newAsyncHttpClient(headers = defaultHeader(api_key, organization)))

template getFromOpenAi(client: HttpClient | AsyncHttpClient;
    relativePath: string): untyped = get(client, OpenAI_BASEURL & relativePath)

template postToOpenAi(client: HttpClient | AsyncHttpClient;
    relativePath: string, requestBody: string = "", multipart: MultipartData = nil): untyped = post(client,
        OpenAI_BASEURL & relativePath, requestBody, multipart)

template deleteFromOpenAi(client: HttpClient | AsyncHttpClient;
    relativePath: string): untyped = delete(client, OpenAI_BASEURL & relativePath)


template makeRequestProc(procName, procType: untyped; requiredParams,
    optionalParams: seq[string]): untyped =
  proc `procName`(body: JsonNode): `procType` =
    result = %*{}
    var 
      required = toHashSet(`requiredParams`)
      optional = toHashSet(`optionalParams`)
      allPossibleParams = required + optional

    for key in body.keys:
      if key in allPossibleParams:
        allPossibleParams.excl(key)
        result[key] = body[key]
      else:
        echo key, " is not a valid key in the ", `procType`, " schema"
        quit(1)

    let omittedRequiredParams = allPossibleParams - optional

    if omittedRequiredParams.len > 0:
      echo omittedRequiredParams, " is a required Parameter in the ",
          `procType`, " schema but has not been provided"
      quit(1)

type
  CompletionRequest = JsonNode

  ChatCompletionRequest = JsonNode

  EditRequest = JsonNode

  ImageRequest = JsonNode

  ImageEditRequest = JsonNode

  ImageVariationRequest = JsonNode

  EmbeddingRequest = JsonNode

  TranscriptionRequest = JsonNode

  TranslationRequest = JsonNode

  SearchRequest = JsonNode

  FileRequest = JsonNode

  AnswerRequest = JsonNode

  ClassificationRequest = JsonNode

  FineTuneRequest = JsonNode

  ModerationRequest = JsonNode

makeRequestProc(parseCompletionRequest, CompletionRequest, @["model"], @[
    "prompt", "suffix", "max_tokens", "temperature", "top_p", "n", "stream",
    "logprobs", "echo", "stop", "presence_penalty", "frequency_penalty",
    "best_of", "logit_bias", "user"])

makeRequestProc(parseChatCompletionRequest, ChatCompletionRequest, @["model",
    "messages"], @["temperature", "top_p", "n", "stream", "stop", "max_tokens",
        "presence_penalty", "frequency_penalty", "logit_bias"])

makeRequestProc(parseEditRequest, EditRequest, @["model", "instruction"], @[
    "instruction", "n", "temperature", "top_p"])

makeRequestProc(parseImageRequest, ImageRequest, @["prompt"], @["n", "size",
    "response_format", "user"])

makeRequestProc(parseImageEditRequest, ImageEditRequest, @["prompt", "image"],
    @["mask", "n", "size", "response_format", "user"])

makeRequestProc(parseImageVariationRequest, ImageVariationRequest, @["image"],
    @["n", "size", "response_format", "user"])

makeRequestProc(parseModerationRequest, ModerationRequest, @["input"], @["model"])

makeRequestProc(parseSearchRequest, SearchRequest, @["query"], @["documents",
    "file", "max_rerank", "user"])

makeRequestProc(parseFileRequest, FileRequest, @["file", "purpose"], @[
    "empty"]) #the empty optionalParams is just so the compiler will shut up

makeRequestProc(parseAnswerRequest, AnswerRequest, @["model", "question",
    "examples", "examples_context"], @["documents", "file", "search_model",
        "max_rerank", "temperature", "logprobs", "max_tokens", "stop", "n",
        "logit_bias", "return_metadata", "return_prompt", "expand", "user"])

makeRequestProc(parseClassificationRequest, ClassificationRequest, @["model",
    "query"], @["examples", "file", "labels", "search_model", "temperature",
        "logprobs", "max_examples", "logit_bias", "return_prompt",
        "return_metadata", "expand", "user"])

makeRequestProc(parseFineTuneRequest, FineTuneRequest, @["training_file"], @[
    "validation_file", "model", "n_epochs", "batch_size",
    "learning_rate_multiplier", "prompt_loss_weight",
    "compute_classification_metrics", "classification_n_classes",
    "classification_positive_class", "classification_betas", "suffix"])

makeRequestProc(parseEmbeddingRequest, EmbeddingRequest, @["model", "input"], @["user"])

makeRequestProc(parseTranscriptionRequest, TranscriptionRequest, @["file",
    "model"], @["prompt", "response_format", "temperature", "language"])

makeRequestProc(parseTranslationRequest, TranslationRequest, @["file",
    "model"], @["prompt", "response_format", "temperature"])


proc createMultiPartData(body: JsonNode, parseBody: proc(body: JsonNode): JsonNode, multipartFields: openArray[string]): MultipartData =
  let 
    verifiedBody = parseBody(body)
    multipartBody = newMultipartData()

  for key in verifiedBody.keys:
      if key in multipartFields:
        let data = ($verifiedBody[key])[1..^2]
        multipartBody.addFiles([(key, data)])  
      else:
        multipartBody[key] = $verifiedBody[key]
  result = multipartBody



proc createCompletion*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates a completion for the provided prompt and parameters
  let verifiedBody = parseCompletionRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/completions", $verifiedBody)


proc createChatCompletion*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates a completion for the chat message
  let verifiedBody = parseChatCompletionRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/chat/completions", $verifiedBody)
  
proc createEdit*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates a new edit for the provided input, instruction, and parameters.
  let verifiedBody = parseEditRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/edits", $verifiedBody)
  
proc createImage*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates an image given a prompt.
  let verifiedBody = parseImageRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/images/generations", $verifiedbody)


proc createImageEdit*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates an edited or extended image given an original image and a prompt.
  
  apiConfig.client.headers["Content-Type"] = "multipart/form-data"
  result = await postToOpenAi(apiConfig.client, "/images/edits", multipart = createMultiPartData(body, parseImageEditRequest, ["image", "mask"]))

proc createImageVariation*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates a variation of a given image.
  
  apiConfig.client.headers["Content-Type"] = "multipart/form-data"
  result = await postToOpenAi(apiConfig.client, "/images/variations", multipart = createMultiPartData(body, parseImageVariationRequest, ["image"]))

proc createEmbedding*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Creates an embedding vector representing the input text.
  
  let verifiedBody = parseEmbeddingRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/embeddings", $verifiedBody)

proc createTranscription*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Transcribes audio into the input language.

  apiConfig.client.headers["Content-Type"] = "multipart/form-data"
  result = await postToOpenAi(apiConfig.client, "/audio/transcriptions", multipart = createMultiPartData(body, parseTranscriptionRequest, ["file"]))

proc createTranslation*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Translates audio into into English.
  
  apiConfig.client.headers["Content-Type"] = "multipart/form-data"
  result = await postToOpenAi(apiConfig.client, "/audio/translations", multipart = createMultiPartData(body, parseTranslationRequest, ["file"]))
  

proc createSearch*(apiConfig: OpenAi_Client | Async_OpenAi_Client; engineId: string,
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## The search endpoint computes similarity scores between provided query and documents. Documents can be passed directly to the API if there are no more than 200 of them.
  ##
  ## To go beyond the 200 document limit, documents can be processed offline and then used for efficient retrieval at query time.
  ##  When `file` is set, the search endpoint searches over all the documents in the given file and returns up to the `max_rerank` number of documents.
  ##  These documents will be returned along with their search scores.
  ##
  ##  The similarity score is a positive score that usually ranges from 0 to 300 (but can sometimes go higher), where a score above 200 usually means the document is semantically similar to the query.
  
  let verifiedBody = parseSearchRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client,
      fmt"/engines/{engineId}/search", $verifiedBody)
 

proc listFiles*(apiConfig: OpenAi_Client | Async_OpenAi_Client): Future[Response | AsyncResponse] {.multisync.} =
  ## Returns a list of files that belong to the user's organization.
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await getFromOpenAi(apiConfig.client, "/files")

proc createFile*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Upload a file that contains document(s) to be used across various endpoints/features.
  ##  Currently, the size of all the files uploaded by one organization can be up to 1 GB.
  ##  Please contact us if you need to increase the storage limit.
  
  apiConfig.client.headers["Content-Type"] = "multipart/form-data"
  result = await postToOpenAi(apiConfig.client, "/file", multipart = createMultiPartData(body, parseFileRequest, ["file"]))


proc deleteFile*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fileId: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Delete a file.
  result = await deleteFromOpenAi(apiConfig.client, fmt"/files/{fileId}")

proc retrieveFile*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fileId: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Returns information about a specific file.
  result = await getFromOpenAi(apiConfig.client, fmt"/file/{fileId}")

proc downloadFile*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fileId: string,
    saveToFileName = fileId): Future[void] =
  ## Returns the contents of the specified file
  result = await httpclient.downloadFile(apiConfig.client, fmt"/file/{fileId}", saveToFileName)

proc createAnswer*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Answers the specified question using the provided documents and examples.
  ## The endpoint first [searches](/docs/api-reference/searches) over provided documents or files to find relevant context.
  ##  The relevant context is combined with the provided examples and question to create the prompt for [completion](/docs/api-reference/completions).
  
  let verifiedBody = parseAnswerRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/answers", $verifiedBody)
  
proc createClassification*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Classifies the specified `query` using provided examples.
  ##
  ## The endpoint first [searches](/docs/api-reference/searches) over the labeled examples
  ## to select the ones most relevant for the particular query. Then, the relevant examples
  ## are combined with the query to construct a prompt to produce the final label via the
  ## [completions](/docs/api-reference/completions) endpoint.
  ##
  ## Labeled examples can be provided via an uploaded `file`, or explicitly listed in the
  ## request using the `examples` parameter for quick tests and small scale use cases.
  
  let verifiedBody = parseClassificationRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/classifications", $verifiedBody)

proc createFineTune*(apiConfig: OpenAi_Client | Async_OpenAi_Client; body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ##  Creates a job that fine-tunes a specified model from a given dataset.
  ##
  ##  Response includes details of the enqueued job including job status and the name of the fine-tuned models once complete.
  ##
  ##  [Learn more about Fine-tuning](/docs/guides/fine-tuning)
  
  let verifiedBody = parseFineTuneRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/fine-tunes", $verifiedBody)

proc listFineTunes*(apiConfig: OpenAi_Client | Async_OpenAi_Client): Future[Response | AsyncResponse] {.multisync.} =
  ## List your organization's fine-tuning jobs
  
  result = await getFromOpenAi(apiConfig.client, "/fine-tunes")

proc retrieveFineTune*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fineTuneId: string): Response |
    Future[AsyncResponse] =
  ## Gets info about the fine-tune job.
  ##
  ## [Learn more about Fine-tuning](/docs/guides/fine-tuning)

  result = await getFromOpenAi(apiConfig.client,
      fmt"/fine-tunes/{fineTuneId}")

proc cancelFineTune*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fineTuneId: string): Response |
    Future[AsyncResponse] =
  ## Immediately cancel a fine-tune job.
  result = await postToOpenAi(apiConfig.client,
      fmt"/fines-tunes/{fineTuneId}/cancel")

proc listFineTuneEvents*(apiConfig: OpenAi_Client | Async_OpenAi_Client; fineTuneId: string): Response |
    Future[AsyncResponse] =
  ## Get fine-grained status updates for a fine-tune job.
  result = await getFromOpenAi(apiConfig.client,
      fmt"/fines-tunes/{fineTuneId}/events")

proc listModels*(apiConfig: OpenAi_Client | Async_OpenAi_Client): Future[Response |
    AsyncResponse] {.multisync.} =
  ## Lists the currently available models, and provides basic information about each one such as the owner and availability.
  result = await getFromOpenAi(apiConfig.client, "/models")
  

proc retrieveModel*(apiConfig: OpenAi_Client | Async_OpenAi_Client; model: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Retrieves a model instance, providing basic information about the model such as the owner and permissioning.
  result = await getFromOpenAi(apiConfig.client, fmt"/models/{model}")

proc deleteModel*(apiConfig: OpenAi_Client | Async_OpenAi_Client; model: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Delete a fine-tuned model. You must have the Owner role in your organization.
  result = await deleteFromOpenAi(apiConfig.client, fmt"/models/{model}")

proc createModeration*(apiConfig: OpenAi_Client | Async_OpenAi_Client;
    body: JsonNode): Future[Response | AsyncResponse] {.multisync.} =
  ## Classifies if text violates OpenAI's Content Policy
  let verifiedBody = parseModerationRequest(body)
  apiConfig.client.headers["Content-Type"] = "application/json"
  result = await postToOpenAi(apiConfig.client, "/moderations", $verifiedBody)