request = require './request'


module.exports.taskCanBeUsed    = false
module.exports.contactCanBeUsed = false
module.exports.alarmCanBeUsed   = false


###
# Alarm model and collection
###
module.exports.Alarm = class Alarm extends Backbone.Model

    urlRoot: "/apps/agenda/alarms"
    @dateFormat = "{Dow} {Mon} {dd} {yyyy} {HH}:{mm}:00"

    @reminderCf = {}

    @setDefaultCf = (description, related) ->
        Alarm.reminderCf.description = description if description
        Alarm.reminderCf.related     = related     if related
        module.exports.alarmCollection.each (model) =>
            model.save Alarm.reminderCf

    defaults: ->
        description: Alarm.reminderCf.description
        related:     Alarm.reminderCf.related
        action:      'DISPLAY'

module.exports.alarmCollection = new Backbone.Collection [], model: Alarm


###
# Contact model and collection
###
module.exports.Contact = class Contact extends Backbone.Model
    urlRoot: '/apps/contacts/contacts'

module.exports.contactCollection = new Backbone.Collection [],
    url: Contact::urlRoot
    model: Contact

Contact.load = (cb) ->
    module.exports.contactCollection.fetch
        success:     -> cb null
        error: (err) -> cb err

###
# Tasks model
# TODO : use a collection
###
module.exports.Task = class Task extends Backbone.Model
    url: ->
      if @isNew() then "/apps/todos/todolists/#{Task.todolistId}/tasks"
      else "/apps/todos/tasks/#{@id}"

    defaults: ->
        done:false

    parse: (data) -> if data.rows then data.rows[0] else data

Task.getOrCreateInbox = (callback) ->
    # task can be used, let's get/create inbox list
    request.get '/apps/todos/todolists', (err, lists) ->

        if err
            module.exports.taskCanBeUsed = false
            return callback err

        if inbox = _.findWhere(lists.rows, title: 'Inbox')
            Task.todolistId = inbox.id
            return callback null

        todolist = title: 'Inbox', parent_id:'tree-node-all'
        request.post '/apps/todos/todolists', todolist, (err, inbox) ->

            if err
                module.exports.taskCanBeUsed = false
                return callback err

            Task.todolistId = inbox.id
            return callback null



###
# Initializer : ask home to see what is installed
# -> fetch contacts
# -> get or create Inbox todolist
###
module.exports.initialize = (callback) ->

    callback ?= ->

    request.get '/api/applications', (err, apps) ->

        return callback err if err

        actions = []

        for app in (apps?.rows or [])
            continue unless app.state is 'installed'

            switch app.slug
                when 'contacts'
                    module.exports.contactCanBeUsed = true
                    actions.push Contact.load
                when 'agenda'
                    module.exports.alarmCanBeUsed   = true
                when 'todos'
                    module.exports.taskCanBeUsed    = true
                    actions.push Task.getOrCreateInbox


        # async.parallel actions, callback
        cnt = actions.length
        err = null
        for action in actions
            action (err) ->
                err ?= err if err
                cnt--
                callback err if cnt is 0


