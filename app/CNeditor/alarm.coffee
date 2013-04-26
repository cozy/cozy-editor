request = require("./request")

# Model that describes a single task
module.exports = class Alarm extends Backbone.Model

    # A remplir par Joseph
    urlRoot: "/apps/agenda/alarms"

    @dateFormat = "{Dow} {Mon} {dd} {yyyy} {HH}:{mm}:00"

    validate: (attrs, options) ->

        errors = []

        if not attrs.description or attrs.description is ""
            errors.push
                field: 'description'
                value: "A description must be set."

        if not attrs.action or attrs.action is ""
            errors.push
                field: 'action'
                value: "An action must be set."

        allowedActions = ['DISPLAY', 'EMAIL']
        if allowedActions.indexOf(attrs.action) is -1
            errors.push
                field: 'action'
                value: "A valid action must be set."

        if not attrs.trigg or not new Date.create(attrs.trigg).isValid()
            errors.push
                field: 'triggdate'
                value: "The date or time format might be invalid. " + \
                        "It must be dd/mm/yyyy and hh:mm."

        if errors.length > 0
            return errors

    getDateObject: ->
        return new Date.create(@get('trigg'))

    getFormattedDate: (formatter) ->
        return @getDateObject().format formatter

    # Private static methods
    noCallback = ->
    isAlarm = (app) -> app.name is 'agenda'
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
