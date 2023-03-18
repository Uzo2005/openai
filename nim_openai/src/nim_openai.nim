# import nim_openai/[client]
import sequtils
import strutils
import json
import tables
import sets

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

# type
#     Bar = enum
#         num = "int"
#         str = "string"
#         arr

#     Foo = object
#         key: string
#         case valueType: Bar
#             of num:
#                 intValue: int
#             of str:
#                 strValue: string
#             of arr:
#                 arrVals: Bar


# proc a(params: varargs[string, `$`]): string =
#     var
#         required = toHashSet(["model", "prompt"])
#         optional = toHashSet(["stop", "n"])

#     var temp = %*{}

#     for param in params:
#         var
#             temp1 = param.split(",")
#             key = temp1[0][2..^2]
#             val = temp1[1..^1].join(",")[1..^2]
#         # echo temp1
#         if key in (required + optional):
#             if key in required:
#                 required.excl(key)
#             temp[key] = %val
#         else:
#             echo key, " is not allowed here"

#     if required.len >= 1:
#         for i in required.items:
#             echo i, " has not been provided"

#     result = $temp

var params = %*{
                "model": "Davinici",
                "messages": [
                                1, 2, 3, 4
                            ],
                "log_probs": 1
                }


proc makea(body: JsonNode): string =
    var 
        temp = %*{}
        required = toHashSet(["model", "stop", "log_probs"])
        optional = toHashSet(["messages", "input"])
        allPossibleParams = required + optional
    
    for key in body.keys:
        if key in allPossibleParams:
            allPossibleParams.excl(key)
            temp[key] = body[key]
        else:
            echo key, " is not a valid key in this schema"
            quit(1)
    
    let omittedRequiredParams = allPossibleParams - optional

    if omittedRequiredParams.len > 0:
        echo omittedRequiredParams, " is a required Parameter but has not been provided"
        quit(1)

    result = $temp

echo makea(params)