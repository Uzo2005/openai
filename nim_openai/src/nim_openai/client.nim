#[
  This Module implements an OpenAI REST API Client In Nim:
    openapi: 3.0.0
    info:
      title: OpenAI API
      description: APIs for sampling from and fine-tuning language models
      version: '1.2.0


  procs:
    listEngines:      Lists the currently available (non-finetuned) models, and provides basic information about each one such as the owner and availability.
    retrieveEngine:   Retrieves a model instance, providing basic information about it such as the owner and availability.
    createCompletion: Creates a completion for the provided prompt and parameters
]#

#When I implement the return types for all the procs, I will just remove all the code duplication and have one function syntax

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

proc setHeaders(api_key: string): HttpHeaders =
  result = newHttpHeaders([("Content-Type", "application/json"), (
      "Authorization", fmt"Bearer {api_key}")])

proc newOpenAiClient*(api_key: string): OpenAi_Api =
  result = OpenAi_Api(API_KEY: api_key, isAsync: false,
      httpClient: newHttpClient(headers = setHeaders(api_key)))

proc newAsyncOpenAiClient*(api_key: string): OpenAi_Api =
  result = OpenAi_Api(API_KEY: api_key, isAsync: true,
      asynchttpClient: newAsyncHttpClient(headers = setHeaders(api_key)))


type
  CompletionRequest = object
    model: string
    prompt: string
    max_tokens: int
    temprature: int
    top_p: int
    n: int
    stream: bool
    logprobs: string #e.g "null"
    stop: string
  ChatCompletionRequest = object
    model: string
    messages: openArray[JsonNode]
  EditRequest = object
    model: string
    input: string
    instruction: string
  ImageRequest = object
    prompt: string
    n: int
    size: string #e.g "1024x1024"
  ImageEditRequest = object
    imageFilePath: string
    maskFilePath: string
    prompt: string
    n: int
    size: string #e.g "1024x1024"
  ImageVariationRequest = object
    imageFilePath: string
    n: int
    size: int
  EmbeddingRequest = object
    model: string
    input: string
  TranscriptionRequest = object
    audioFilePath: string
    model: string
  TranslationRequest = object
    audioFilePath: string
    model: string
  SearchRequest = object
    documents: openArray[string]
    query: string
  CreateFileRequest = object
    filePath: string
    purpose: string #e.g "Finetune"
  AnswerRequest = object
    documents: openArray[string]
    question: string
    search_model: string
    model: string
    examples_context: string
    examples: openArray[string]
    max_tokens: int
    stop: openArray[string]
  ClassificationRequest = object
    examples: openArray[array[2, string]]
    labels: openArray[string]
    query: string
    search_model: string
    model: string
  FineTuneRequest = object
    training_filePath: string
  ModerationRequest = object
    input: string


#In every type's init function I need to verify that the required params are set
#the params would be the required ones first and then others as varargs
proc createCompletionRequest*(model: string, prompt: string | openArray[
    int] | openArray[openArray[int]] = "<|endoftext|>",
        suffix: string = "", max_tokens: Natural = 16, temperature: range[
            0.0..2.0] = 1, top_p: range[0.0..1.0] = 1, n: range[
                1..128] = 1, stream: bool = false, logprobs: range[0..5] = 0,
                    echo: bool = false, stop: string | array[1, string] | array[
                        2, string] | array[3, string] | array[4,
                        string] = "", presence_penalty: range[-2.0..2.0] = 0,
                            frequency_penalty: int) = discard

type
  Model = object
    id: string
    `object`: string
    created: int
    owned_by: string

  Engine = object
    id: string
    `object`: string
    created: int
    ready: bool

  OpenAiFile = object
    id: string
    `object`: string
    bytes: int
    created_at: int
    filename: string
    purpose: string
    status: string
    # status_details: object

  Finetune = object
    id: string
    `object`: string
    created_at: int
    updated_at: int
    model: string
    fine_tuned_model: string
    organization_id: string
    status: string
    # hyperparams: object
    training_files: openArray[OpenAiFile]
    validation_files: openArray[OpenAiFile]
    result_files: openArray[OpenAiFile]
    events: openArray[FineTuneEvent]

  FineTuneEvent = object
    `object`: string
    created_at: int
    level: string
    message: string




proc getAsync(client: AsyncHttpClient; relativePath: string): Future[
    AsyncResponse] =

  result = client.get(OPEN_AI_API_URL & relativePath)


proc getSync(client: HttpClient; relativePath: string): Response =

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



proc createCompletion*(apiConfig: OpenAi_Api;
    body: CompletionRequest): Response =
  ## Creates a completion for the provided prompt and parameters
  result = postSync(apiConfig.httpClient, "/completions", $(%body))

proc createCompletionAsync*(apiConfig: OpenAi_Api;
    body: CompletionRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/completions", $(%body))

proc createChatCompletion*(apiConfig: OpenAi_Api;
    body: ChatCompletionRequest): Response =
  ## Creates a completion for the chat message
  result = postSync(apiConfig.httpClient, "/chat/completions", $(%body))

proc createChatCompletionAsync*(apiConfig: OpenAi_Api;
    body: ChatCompletionRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/chat/completions", $(%body))

proc createEdit*(apiConfig: OpenAi_Api; body: EditRequest): Response =
  ## Creates a new edit for the provided input, instruction, and parameters.
  result = postSync(apiConfig.httpClient, "/edits", $(%body))

proc createEditAsync*(apiConfig: OpenAi_Api; body: EditRequest): Future[
    AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/edits", $(%body))

proc createImage*(apiConfig: OpenAi_Api; body: ImageRequest): Response =
  ## Creates an image given a prompt.
  result = postSync(apiConfig.httpClient, "/images/generations", $(%body))

proc createImageAsync*(apiConfig: OpenAi_Api; body: ImageRequest): Future[
    AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/images/generations", $(%body))

proc createImageEdit*(apiConfig: OpenAi_Api; body: ImageEditRequest): Response =
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
  result = postSync(apiConfig.httpClient, "/images/edits", $newBody)

proc createImageEditAsync*(apiConfig: OpenAi_Api;
    body: ImageEditRequest): Future[AsyncResponse] =
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
  result = postAsync(apiConfig.asynchttpClient, "/images/edits", $newBody)

proc createImageVariation*(apiConfig: OpenAI_Api;
    body: ImageVariationRequest): Response =
  ## Creates a variation of a given image.
  let
    image = readFile(body.imageFilePath)
    newBody = %*{
                  "image": %image,
                  "n": %body.n,
                  "size": %body.size
      }
  result = postSync(apiConfig.httpClient, "/images/variations", $newBody)

proc createImageVariationAsync*(apiConfig: OpenAi_Api;
    body: ImageVariationRequest): Future[AsyncResponse] =
  let
    image = readFile(body.imageFilePath)
    newBody = %*{
                  "image": %image,
                  "n": %body.n,
                  "size": %body.size
      }
  result = postAsync(apiConfig.asynchttpClient, "/images/variations", $newBody)

proc createEmbedding*(apiConfig: OpenAi_Api; body: EmbeddingRequest): Response =
  ## Creates an embedding vector representing the input text.
  result = postSync(apiConfig.httpClient, "/embeddings", $(%body))

proc createEmbeddingAsync*(apiConfig: OpenAi_Api;
    body: EmbeddingRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/embeddings", $(%body))

proc createTranscription*(apiConfig: OpenAi_Api;
    body: TranscriptionRequest): Response =
  ## Transcribes audio into the input language.
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  result = postSync(apiConfig.httpClient, "/audio/transcriptions", $newBody)

proc createTranscriptionAsync*(apiConfig: OpenAi_Api;
    body: TranscriptionRequest): Future[AsyncResponse] =
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  result = postAsync(apiConfig.asynchttpClient, "/audio/transcriptions", $newBody)

proc createTranslation*(apiConfig: OpenAi_Api;
    body: TranslationRequest): Response =
  ## Translates audio into into English.
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  result = postSync(apiConfig.httpClient, "/audio/translations", $newBody)

proc createTranslationAsync*(apiConfig: OpenAi_Api;
    body: TranslationRequest): Future[AsyncResponse] =
  let
    audioFile = readFile(body.audioFilePath)
    newBody = %*{
                  "file": %audioFile,
                  "model": %body.model
      }
  result = postAsync(apiConfig.asynchttpClient, "/audio/translations", $newBody)

proc createSearch*(apiConfig: OpenAi_Api; engineId: string,
    body: SearchRequest): Response =
  ## The search endpoint computes similarity scores between provided query and documents. Documents can be passed directly to the API if there are no more than 200 of them.
  ##
  ## To go beyond the 200 document limit, documents can be processed offline and then used for efficient retrieval at query time.
  ##  When `file` is set, the search endpoint searches over all the documents in the given file and returns up to the `max_rerank` number of documents.
  ##  These documents will be returned along with their search scores.
  ##
  ##  The similarity score is a positive score that usually ranges from 0 to 300 (but can sometimes go higher), where a score above 200 usually means the document is semantically similar to the query.

  result = postSync(apiConfig.httpClient, fmt"/engines/{engineId}/search", $(%body))

proc createSearchAsync*(apiConfig: OpenAi_Api; engineId: string,
    body: SearchRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, fmt"/engines/{engineId}/search",
      $(%body))

proc listFiles*(apiConfig: OpenAi_Api): Response =
  ## Returns a list of files that belong to the user's organization.
  result = getSync(apiConfig.httpClient, "/files")

proc listFilesAsync*(apiConfig: OpenAi_Api): Future[AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, "/files")

proc createFile*(apiConfig: OpenAi_Api; body: CreateFileRequest): Response =
  ## Upload a file that contains document(s) to be used across various endpoints/features.
  ##  Currently, the size of all the files uploaded by one organization can be up to 1 GB.
  ##  Please contact us if you need to increase the storage limit.
  let
    file = readFile(body.filePath)
    newBody = %*{
                    "file": %file,
                    "purpose": %body.purpose
      }
  result = postSync(apiConfig.httpClient, "/file", $(%newBody))

proc createFileAsync*(apiConfig: OpenAi_Api; body: CreateFileRequest): Future[
    AsyncResponse] =
  let
    file = readFile(body.filePath)
    newBody = %*{
                    "file": %file,
                    "purpose": %body.purpose
      }
  result = postAsync(apiConfig.asynchttpClient, "/file", $(%newBody))

proc deleteFile*(apiConfig: OpenAi_Api; fileId: string): Response =
  ## Delete a file.
  result = deleteSync(apiConfig.httpClient, fmt"/files/{fileId}")

proc deleteFileAsync*(apiConfig: OpenAi_Api; fileId: string): Future[
    AsyncResponse] =
  result = deleteAsync(apiConfig.asynchttpClient, fmt"/files/{fileId}")

proc retrieveFile*(apiConfig: OpenAi_Api; fileId: string): Response =
  ## Returns information about a specific file.
  result = getSync(apiConfig.httpClient, fmt"/file/{fileId}")

proc retrieveFileAsync*(apiConfig: OpenAi_Api; fileId: string): Future[
    AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, fmt"/file/{fileId}")

proc downloadFile*(apiConfig: OpenAi_Api; fileId: string,
    saveToFileName = fileId): Future[void] =
  ## Returns the contents of the specified file
  let client = newAsyncHttpClient()
  result = httpclient.downloadFile(client, fmt"/file/{fileId}", saveToFileName)

proc createAnswer*(apiConfig: OpenAi_Api; body: AnswerRequest): Response =
  ## Answers the specified question using the provided documents and examples.
  ## The endpoint first [searches](/docs/api-reference/searches) over provided documents or files to find relevant context.
  ##  The relevant context is combined with the provided examples and question to create the prompt for [completion](/docs/api-reference/completions).

  result = postSync(apiConfig.httpClient, "/answers", $(%body))

proc createAnswerAsync*(apiConfig: OpenAi_Api; body: AnswerRequest): Future[
    AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/answers", $(%body))

proc createClassifications*(apiConfig: OpenAi_Api;
    body: ClassificationRequest): Response =
  ## Classifies the specified `query` using provided examples.
  ##
  ## The endpoint first [searches](/docs/api-reference/searches) over the labeled examples
  ## to select the ones most relevant for the particular query. Then, the relevant examples
  ## are combined with the query to construct a prompt to produce the final label via the
  ## [completions](/docs/api-reference/completions) endpoint.
  ##
  ## Labeled examples can be provided via an uploaded `file`, or explicitly listed in the
  ## request using the `examples` parameter for quick tests and small scale use cases.

  result = postSync(apiConfig.httpClient, "/classifications", $(%body))

proc createClassificationsAsync*(apiConfig: OpenAi_Api;
    body: ClassificationRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/classifications", $(%body))

proc createFineTune*(apiConfig: OpenAi_Api; body: FineTuneRequest): Response =
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
  result = postSync(apiConfig.httpClient, "/fine-tunes", $(%newBody))

proc createFineTuneAsync*(apiConfig: OpenAi_Api; body: FineTuneRequest): Future[
    AsyncResponse] =
  let
    training_file = readFile(body.training_filePath)
    newBody = %*{
                  "training_file": %training_file
      }
  result = postAsync(apiConfig.asynchttpClient, "/fine-tunes", $(%newBody))

proc listFineTunes*(apiConfig: OpenAi_Api): Response =
  ## List your organization's fine-tuning jobs
  result = getSync(apiConfig.httpClient, "/fine-tunes")

proc listFineTunesAsync*(apiConfig: OpenAi_Api): Future[AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, "/fine-tunes")

proc retrieveFineTune*(apiConfig: OpenAi_Api; fineTuneId: string): Response =
  ## Gets info about the fine-tune job.
  ##
  ## [Learn more about Fine-tuning](/docs/guides/fine-tuning)

  result = getSync(apiConfig.httpClient, fmt"/fine-tunes/{fineTuneId}")

proc retrieveFineTuneAsync*(apiConfig: OpenAi_Api; fineTuneId: string): Future[
    AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, fmt"/fine-tunes/{fineTuneId}")

proc cancelFineTune*(apiConfig: OpenAi_Api; fineTuneId: string): Response =
  ## Immediately cancel a fine-tune job.
  result = postSync(apiConfig.httpClient, fmt"/fines-tunes/{fineTuneId}/cancel")

proc cancelFineTuneAsync*(apiConfig: OpenAi_Api; fineTuneId: string): Future[
    AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient,
      fmt"/fines-tunes/{fineTuneId}/cancel")

proc listFineTuneEvents*(apiConfig: OpenAi_Api; fineTuneId: string): Response =
  ## Get fine-grained status updates for a fine-tune job.
  result = getSync(apiConfig.httpClient, fmt"/fines-tunes/{fineTuneId}/events")

proc listFineTuneEventsAsync*(apiConfig: OpenAi_Api;
    fineTuneId: string): Future[AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient,
      fmt"/fines-tunes/{fineTuneId}/events")

proc listModels*(apiConfig: OpenAi_Api): Response =
  ## Lists the currently available models, and provides basic information about each one such as the owner and availability.
  result = getSync(apiConfig.httpClient, "/models")

proc listModelsAsync*(apiConfig: OpenAi_Api): Future[AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, "/models")

proc retrieveModel*(apiConfig: OpenAi_Api; model: string): Response =
  ## Retrieves a model instance, providing basic information about the model such as the owner and permissioning.
  result = getSync(apiConfig.httpClient, fmt"/models/{model}")

proc retrieveModelAsync*(apiConfig: OpenAi_Api; model: string): Future[
    AsyncResponse] =
  result = getAsync(apiConfig.asynchttpclient, fmt"/models/{model}")

proc deleteModel*(apiConfig: OpenAi_Api; model: string): Response =
  ## Delete a fine-tuned model. You must have the Owner role in your organization.
  result = deleteSync(apiConfig.httpClient, fmt"/models/{model}")

proc deleteModelAsync*(apiConfig: OpenAi_Api; model: string): Future[
    AsyncResponse] =
  result = deleteAsync(apiConfig.asynchttpClient, fmt"/models/{model}")

proc createModeration*(apiConfig: OpenAi_Api;
    body: ModerationRequest): Response =
  ## Classifies if text violates OpenAI's Content Policy
  result = postSync(apiConfig.httpClient, "/moderations", $(%body))

proc createModerationAsync*(apiConfig: OpenAi_Api;
    body: ModerationRequest): Future[AsyncResponse] =
  result = postAsync(apiConfig.asynchttpClient, "/moderations", $(%body))

