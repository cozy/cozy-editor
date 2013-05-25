class SocketListener extends CozySocketListener

    models:
        'task' : require 'CNeditor/task'
        'alarm': require 'CNeditor/alarm'

    events:
        ['alarm.update', 'alarm.delete',
         'task.update', 'task.delete']

    onRemoteDelete: (model) ->
        model.trigger 'destroy', model, model.collection, {}

module.exports = new SocketListener()