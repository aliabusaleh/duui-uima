-- Bind static classes from java
StandardCharsets = luajava.bindClass("java.nio.charset.StandardCharsets")
sentence = luajava.bindClass("de.tudarmstadt.ukp.dkpro.core.api.segmentation.type.Sentence")
utils = luajava.bindClass("org.apache.uima.fit.util.JCasUtil")

-- This "serialize" function is called to transform the CAS object into an stream that is sent to the annotator
-- Inputs:
--  - inputCas: The actual CAS object to serialize
--  - outputStream: Stream that is sent to the annotator, can be e.g. a string, JSON payload, ...
function serialize(inputCas, outputStream, params)
    -- Get data from CAS
    local doc_text = inputCas:getDocumentText()

    local labels_string = params["labels"]
    local selection = params["selection"]
    local multi_label = params["multiLabel"]
    local clear_gpu_cache_after = params["clearGpuCacheAfter"]

    if multi_label ~= nil and multi_label == "false" then
        multi_label = false
    else
        multi_label = true
    end

    if clear_gpu_cache_after ~= nil then
        clear_gpu_cache_after = tonumber(clear_gpu_cache_after)
    else
        clear_gpu_cache_after = 500
    end

    local selection_array = {}
    if selection ~= nil then
       local selectionSet = utils:select(inputCas, luajava.bindClass(selection)):iterator()

       while selectionSet:hasNext() do
           local s = selectionSet:next()
           local tSelection = {
               text = s:getCoveredText(),
               iBegin = s:getBegin(),
               iEnd = s:getEnd()
               }
           table.insert(selection_array, tSelection)
       end

    end

    local labels = {}
    for label in string.gmatch(labels_string, "([^,]+)") do
        table.insert(labels, label)
    end

    -- Encode data as JSON object and write to stream
    -- TODO Note: The JSON library is automatically included and available in all Lua scripts
    outputStream:write(json.encode({
        doc_text = doc_text,
        labels = labels,
        selection = selection_array,
        multi_label = multi_label,
        clear_gpu_cache_after = clear_gpu_cache_after,
    }))
end

-- This "deserialize" function is called on receiving the results from the annotator that have to be transformed into a CAS object
-- Inputs:
--  - inputCas: The actual CAS object to deserialize into
--  - inputStream: Stream that is received from to the annotator, can be e.g. a string, JSON payload, ...
function deserialize(inputCas, inputStream)
    -- Get string from stream, assume UTF-8 encoding
    local inputString = luajava.newInstance("java.lang.String", inputStream:readAllBytes(), StandardCharsets.UTF_8)

    -- Parse JSON data from string into object
    local results = json.decode(inputString)
    for i, label in ipairs(results["labels"]) do
        local categoryCoveredTagged = luajava.newInstance("org.hucompute.textimager.uima.type.category.CategoryCoveredTagged", inputCas)
        categoryCoveredTagged:setValue(label["label"])
        categoryCoveredTagged:setScore(label["score"])
        categoryCoveredTagged:setBegin(label["iBegin"])
        categoryCoveredTagged:setEnd(label["iEnd"])
        categoryCoveredTagged:addToIndexes()
    end
end
