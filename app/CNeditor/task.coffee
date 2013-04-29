request = require("./request")

# Model that describes a single task
module.exports = class Task extends Backbone.Model

    url: ->
      if @isNew() then "/apps/todos/todolists/#{Task.todolistId}/tasks"
      else "/apps/todos/tasks/#{@id}"

    defaults: ->
        done:false

    parse: (data) -> if data.rows then data.rows[0] else data

    # Private static methods
    noCallback = ->
    isTodo = (app) -> app.name is 'todos'
    isFromNote = (todolist) -> todolist.title is 'Inbox'

    getApps = -> request.get '/api/applications', noCallback

    checkTodoInstalled = (apps) ->
        return true if apps.rows.some isTodo
        return $.Deferred().reject()

    getLists = -> request.get '/apps/todos/todolists', noCallback

    inboxExists = (lists) ->
        inbox = _.find lists.rows, isFromNote
        return inbox if inbox
        return $.Deferred().reject('noinbox')

    createInbox = (err) ->
        return err if err isnt 'noinbox'
        todolist = title: 'Inbox', parent_id:'tree-node-all'
        request.post '/apps/todos/todolists', todolist, noCallback

    # Static methods
    @initialize = (callback) ->
        getApps()
        .then(checkTodoInstalled)
        .then(getLists)
        .then(inboxExists)
        .then(null, createInbox) # if doesn't exist, create
        .done((inbox) ->
            Task.todolistId = inbox.id
            Task.canBeUsed = true
            callback true)
        .fail((err) ->
            Task.canBeUsed = false
            callback false)
