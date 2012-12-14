fs = require('fs')
express = require('express')
app = express()

app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)

app.use("/", express.static(__dirname + '/../public'))

app.get '/records/', (req, res) ->
    # list test files
    files = fs.readdirSync('../test/test-cases/')
    result = ''
    for fileName in files
        filePath = '../test/test-cases/'+fileName
        result += ',' + fs.readFileSync(filePath, 'utf8')
    result = '[' + result.substr(1) + ']'
    res.send result

app.post '/records/', (req, res) ->
    console.log "SAVE records"
    newFileNum = newFileNumber()+''
    console.log newFileNum
    console.log newFileNum.length
    zeros = newFilledArray(4-newFileNum.length,'0')
    console.log zeros
    fileName = zeros.join('') + newFileNum + '-' + req.body.title
    console.log req.body
    data = 
        title    : req.body.title
        sequence : req.body.sequence
    path = '../test/test-cases/' +  fileName
    fs.writeFileSync(path, JSON.stringify(data))
    
    # client.set "sequence-#{title}", JSON.stringify(sequence), ->
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

app.listen 3000