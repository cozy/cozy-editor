
module.exports = class ContactPopover


    constructor: ->

        @el = document.createElement('DIV')
        @el.id = 'contactpopover'

        @isOn = false


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

        @el.innerHTML = html
        segment.appendChild @el

        @isOn = true

    # convert a contact datapoint to html
    dp2html: (dp) ->
        value = dp.value.replace "\n", '<br />'
        if dp.name in ['other', 'about']
            name = dp.type
        else
            name = dp.type + ' '+ dp.name

        return "<dt>#{name}</dt><dd>#{value}</dd>"

