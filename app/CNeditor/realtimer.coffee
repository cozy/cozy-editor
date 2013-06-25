ExternalModels = require './externalmodels'

class SocketListener extends CozySocketListener

    models:
        'task' :   ExternalModels.Task
        'alarm':   ExternalModels.Alarm
        'contact': ExternalModels.Contact

    events:
        ['alarm.update', 'alarm.delete',
        'contact.create', 'contact.update', 'contact.delete',
         'task.update', 'task.delete']

    onRemoteCreate: (model) ->
        for collection in @collections
            if model instanceof collection.model
                collection.add model

    onRemoteDelete: (model) ->
        model.trigger 'destroy', model, model.collection, {}


realtimer = new SocketListener()
realtimer.watch ExternalModels.contactCollection
realtimer.watch ExternalModels.alarmCollection
module.exports = realtimer

