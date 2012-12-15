fs = require('fs')
express = require('express')
app = express()

app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use("/", express.static(__dirname + '/../public'))


getAllRecords = (req, res) ->
    files = fs.readdirSync('../test/test-cases/')
    fileList = []
    for fileName in files
        filePath = '../test/test-cases/' + fileName
        fileList.push
            filePath   : filePath
            fileName   : fileName
            recordStrg : fs.readFileSync(filePath, 'utf8')
    
    fileList.sort (a,b)->
        return a.fileName > b.fileName

    result = ''
    for file in fileList
        result += ',' + file.recordStrg
    result = '[' + result.substr(1) + ']'
    res.send result


saveToFile = (req, res) ->
    newFileNum = newFileNumber()+''
    zeros = newFilledArray(4-newFileNum.length,'0')
    zeros = zeros.join('')
    fileName = zeros + newFileNum + '-' + req.body.title
    data = 
        id          : newFileNum
        fileName    : fileName
        title       : req.body.title
        description : req.body.description
        sequence    : req.body.sequence
    path = '../test/test-cases/' +  fileName
    fs.writeFileSync(path, JSON.stringify(data))
    res.send
        id          : newFileNum
        title       : req.body.title
        fileName    : fileName

deleteRecord = (req,res) ->
    console.log "start delete " + req.body.fileName
    path = '../test/test-cases/' + req.body.fileName
    fs.unlink path,(err)->
        if err
            res.send 'ko'
        else
            res.send 'ok'

newFileNumber = () ->
    # list test files
    files = fs.readdirSync('../test/test-cases/')
    lastFileNumber = 0
    for fileName in files
        lastFileNumber = Math.max(lastFileNumber,parseInt(fileName.substr(0,4)))
    console.log lastFileNumber
    return lastFileNumber + 1

newFilledArray = (length, val) ->
    array = []
    i = 0
    while i < length
        array[i] = val
        i++
    return array

app.put '/records/', deleteRecord
app.get '/records/', getAllRecords
app.post '/records/', saveToFile
app.listen 3000