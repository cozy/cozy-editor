class SocketListener extends CozySocketListener

    models:
        'task' : require 'CNeditor/task'
        'alarm': require 'CNeditor/alarm'
        'contact': require 'CNeditor/contact'

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

module.exports = new SocketListener()