# IntentManager = require '../lib/intent_manager'

module.exports = class ContactPopover

    # intentManager: new IntentManager()
    #

    constructor: ->

        @talker = new Talker(window.parent,'*')
        @el = document.createElement('DIV')
        @el.id = 'contactpopover'

        @isOn = false

    send : (nameSpace,intent, timeout) ->
        @talker.timeout = if timeout then timeout else TIMEOUT
        @talker.send('nameSpace',intent)

    hide: ->

        oldcontactseg = null

        if @isOn and oldcontactseg = @el.parentNode
            oldcontactseg.removeChild @el

        @isOn = false

        return oldcontactseg

    show: (segment, model) ->

        datapoints = model.get 'datapoints'
        html = '<dl class="dl-horizontal">'
        html += @dp2html dp for dp in datapoints
        html += '</dl>'
        html += "<a>éditer</a>"

        @el.innerHTML = html
        segment.appendChild @el

        # @el.lastChild.addEventListener 'click', (e)->
        @el.addEventListener 'click', (e)=>
            if e.ctrlKey
                target = '_blank'
            else
                target = '_parent'
            intent =
                type  : 'goto'
                params:
                    appUrl : 'contacts/contact/' + model.id
                    target : target

            timeout = 10800000 # 3 hours
            choosePhoto_answer = @choosePhoto_answer
            @send('nameSpace',intent, timeout)
            console.log "turlututu"


        @isOn = true

    # convert a contact datapoint to html
    dp2html: (dp) ->
        value = dp.value.replace "\n", '<br />'
        if dp.name in ['other', 'about']
            name = dp.type
        else
            name = dp.type + ' '+ dp.name

        return "<dt>#{name}</dt><dd>#{value}</dd>"

