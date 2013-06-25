
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

        html = '<dl class="dl-horizontal">'
        for dp in model.get 'datapoints'
            value = dp.value.replace "\n", '<br />'
            if dp.name is 'other' or dp.name is 'about' then name = dp.type
            else name = dp.type + ' '+ dp.name.replace 'smail', 'postal'
            html += "<dt>#{name}</dt><dd>#{value}</dd>"
        html += '</dl>'

        @el.innerHTML = html
        segment.appendChild @el

        @isOn = true