request = require("./request")

# Model that describes a single task
module.exports = class Contact extends Backbone.Model

    urlRoot: "/apps/contacts/contacts"


    @makeCollection = ->
        new Backbone.Collection [],
            model: Contact
            url: -> Contact::urlRoot

    # Static methods
    @initialize = (callback) ->

        callback ?= ->

        isContacts = (app) -> app.name is 'contacts'

        request.get '/api/applications', (err, apps) ->

            err = 'notinstalled' if not err and not apps.rows.some isContacts

            if err
                Contact.error = err
                callback Contact.canBeUsed = false
            else
                callback Contact.canBeUsed = true

