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

    getApps = (callback) -> request.get '/api/applications', callback

    checkTodoInstalled = (apps, callback) ->
        if apps.rows.some isTodo then callback null, true
        else callback 'notinstalled', false

    getLists = (callback) ->
        request.get '/apps/todos/todolists', callback

    checkInboxExists = (lists, callback) ->
        inbox = _.find lists.rows, isFromNote
        if inbox then callback null, inbox
        else callback 'noinbox'

    createInbox = (callback) ->
        todolist = title: 'Inbox', parent_id:'tree-node-all'
        request.post '/apps/todos/todolists', todolist, callback

    # Static methods
    @initialize = (callback) ->

        fail = (err) ->
            Task.canBeUsed = false
            Task.error = err
            callback false if typeof callback is 'function'

        success = (inbox) ->
            Task.todolistId = inbox.id
            Task.canBeUsed = true
            callback true if typeof callback is 'function'


        getApps (err, apps) ->
            return fail err if err

            checkTodoInstalled apps, (err, isInstalled) ->
                return fail err if err

                getLists (err, lists) ->
                    return fail err if err

                    checkInboxExists lists, (err, inbox) ->
                        return success inbox if inbox
                        return fail err if err isnt 'noinbox'

                        createInbox (err, inbox) ->
                            return fail err if err
                            success inbox
