###*
 * A simple server to save tests recorded in the client
 * Runs on port 3000 (http://localhost:3000)
 * Paths :
 | Path     | Method | Description          |
 | /        | all    | ../public/index.html |
 | /records | put    | deleteRecord         |
 | /records | get    | get                  |
 | /records | post   | save                 |
 | /pastes  | post   | save pastes data     |
###

fs = require('fs')
http = require('http')
express = require('express')
app = express()

app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use("/", express.static(__dirname + '/../public'))


testDirPath  = '../test/test-cases/'
pasteDirPath = '../test/paste-data-exemples/'
pasteDataFile = '../test/paste-data/paste-data.json'

getAllRecords = (req, res) ->
    files = fs.readdirSync(testDirPath)
    fileList = []
    for fileName in files
        filePath = testDirPath + fileName
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


getPasteData = (req, res) ->
    data = fs.readFileSync(pasteDataFile, 'utf8')
    res.send data


saveToFile = (req, res) ->
    reqData = req.body

    newFileNum = newFileNumber()+''
    zeros      = newFilledArray(4-newFileNum.length,'0')
    zeros      = zeros.join('')
    fileName   = zeros + newFileNum + '-' + reqData.title
    data       =
        id           : newFileNum
        fileName     : fileName
        title        : reqData.title
        description  : reqData.description
        sequence     : reqData.sequence
        initialState : reqData.initialState
        finalState   : reqData.finalState
    path = testDirPath +  fileName
    fs.writeFileSync(path, JSON.stringify(data))
    res.send
        id          : newFileNum
        title       : reqData.title
        fileName    : fileName


savePastesToFile = (req, res) ->

    newFileNum = newFileNumber(pasteDirPath)+''
    zeros      = newFilledArray(4-newFileNum.length,'0')
    zeros      = zeros.join('')
    fileName   = zeros + newFileNum + '-paste-data-exemple'
    path = pasteDirPath +  fileName
    content = ''
    console.log req.body
    for html in req.body
        content += '\n\n Paste data stringified :\n' + JSON.stringify(html)

    fs.writeFileSync(path, content)

    res.send
        id          : newFileNum
        fileName    : fileName


deleteRecord = (req,res) ->
    path = testDirPath + req.body.fileName
    fs.unlink path,(err)->
        if err
            res.send 'ko'
        else
            res.send 'ok'


newFileNumber = (dirPath) ->
    # list test files
    if !dirPath
        dirPath = testDirPath
    files = fs.readdirSync(dirPath)
    lastFileNumber = 0
    for fileName in files
        lastFileNumber = Math.max(lastFileNumber,parseInt(fileName.substr(0,4),10))
    return lastFileNumber + 1


newFilledArray = (length, val) ->
    array = []
    i = 0
    while i < length
        array[i] = val
        i++
    return array

# app.put  '/editor/records/' , deleteRecord
# app.get  '/editor/records/' , getAllRecords
# app.post '/editor/records/' , saveToFile
# app.post '/editor/pastes/' ,  savePastesToFile
# app.get  '/editor/pastes/' ,  getPasteData

app.put  '/records/' , deleteRecord
app.get  '/records/' , getAllRecords
app.post '/records/' , saveToFile
app.post '/pastes/' ,  savePastesToFile
app.get  '/pastes/' ,  getPasteData
port = 3000
server = http.createServer(app)

initializer = require 'cozy-realtime-adapter'
initializer server: server, ['task.update', 'task.delete', 'alarm.update', 'alarm.delete']


server.listen port
console.log "editor listing on port " + port
