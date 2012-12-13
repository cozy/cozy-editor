redis = require("redis")
client = redis.createClient()

express = require('express')
app = express()

app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use("/", express.static(__dirname + '/../public'))

app.get '/records/', (req, res) ->
    client.keys "sequence-*", (err, keys) ->
        console.log keys
        
        client.mget keys, (err, records) ->
            console.log err
            
            console.log records
            result = []
            for i in [0..keys.length-1]
                try
                    sequence = JSON.parse records[i]
                catch error
                    sequence = ""

                if keys[i]?
                    result.push
                        title: keys[i].substring("sequence-".length)
                        sequence: sequence

            res.send result

app.put '/records/', (req, res) ->
    title = req.body.title
    client.set "sequence-#{title}", null, ->
        client.del "sequence-#{title}", ->
            res.send 'ok'

app.post '/records/', (req, res) ->
    sequence = req.body.sequence
    title = req.body.title
    console.log sequence
    
    client.set "sequence-#{title}", JSON.stringify(sequence), ->
        res.send 'ok'

app.listen 3000
