request = require("lib/request")

# Model that describes a single task
module.exports = class Alarm extends Backbone.Model

    # A remplir par Joseph
    url: ->
      if @isNew() then "/apps/todos/todolists/#{Task.todolistId}/tasks"
      else "/apps/todos/tasks/#{@id}"

    defaults: ->
        done: false


    # Private static methods
    noCallback = ->
    isAlarm = (app) -> app.name is 'todos'
    getApps = -> request.get '/api/applications', noCallback
    checkAlarmInstalled = (apps) ->
        return true if apps.rows.some isAlarm
        return $.Deferred().reject()

    # Static methods
    @initialize = (callback) ->
        getApps()
        .then(checkAlarmInstalled)
        .then((inbox) ->
            Alarm.canBeUsed = true
            callback true)
        .fail((err) ->
            Alarm.canBeUsed = false
            callback false)
