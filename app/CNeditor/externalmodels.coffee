request = require './request'


module.exports.taskCanBeUsed    = false
module.exports.contactCanBeUsed = false
module.exports.alarmCanBeUsed   = false


###
# Alarm model and collection
###
module.exports.Alarm = class Alarm extends Backbone.Model

    urlRoot: "alarms"
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
    urlRoot: 'contacts'

    @load = (cb) ->
        module.exports.contactCollection.fetch
            success:     -> cb null
            error: (err) -> cb err

module.exports.contactCollection = new Backbone.Collection [],
    url: Contact::urlRoot
    model: Contact

###
# Tasks model
# TODO : use a collection
###
module.exports.Task = class Task extends Backbone.Model
    urlRoot: "tasks"

    defaults: -> done: false


###
# Initializer : ask home to see what is installed
# -> fetch contacts
# -> get or create Inbox todolist
###
module.exports.initialize = (callback) ->

    module.exports.contactCanBeUsed = true
    module.exports.alarmCanBeUsed   = true
    module.exports.taskCanBeUsed    = true
    Contact.load callback

