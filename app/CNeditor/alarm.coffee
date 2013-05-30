request = require("./request")

# Model that describes a single task
module.exports = class Alarm extends Backbone.Model

    urlRoot: "/apps/agenda/alarms"

    @dateFormat = "{Dow} {Mon} {dd} {yyyy} {HH}:{mm}:00"

    defaults: ->
        action: 'DISPLAY'

    validate: (attrs, options) ->

        errors = []

        if not attrs.description or attrs.description is ""
            errors.push
                field: 'description'
                value: "A description must be set."

        if not attrs.trigg or not new Date.create(attrs.trigg).isValid()
            errors.push
                field: 'triggdate'
                value: "The date or time format might be invalid. " + \
                        "It must be \"dd/mm/yyyy hh:mm\"."

        if errors.length > 0
            return errors

    getDateObject: ->
        return new Date.create(@get('trigg'))

    getFormattedDate: (formatter) ->
        return @getDateObject().format formatter

    @makeCollection = ->
        new Backbone.Collection [],
            model: Alarm

    # Static methods
    @initialize = (callback) ->

        callback ?= ->

        isAgenda = (app) -> app.name is 'agenda'

        request.get '/api/applications', (err, apps) ->

            err = 'notinstalled' if not err and not apps.rows.some isAgenda

            if err
                Contact.error = err
                callback Alarm.canBeUsed = false
            else
                callback Alarm.canBeUsed = true