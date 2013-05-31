logging = require './logging'


module.exports = class History

    HISTORY_SIZE = 100

    constructor: (@editor) ->
        @index         = HISTORY_SIZE - 1
        @history       = new Array HISTORY_SIZE
        @historySelect = new Array HISTORY_SIZE
        @historyScroll = new Array HISTORY_SIZE
        @historyPos    = new Array HISTORY_SIZE
        @modifiedTask  = new Array HISTORY_SIZE


    ###
    #  HISTORY MANAGEMENT:
    # 1. _addHistory (Save html code, selection markers, positions...)
    # 2. undoPossible (Return true only if unDo can be called)
    # 3. redoPossible (Return true only if reDo can be called)
    # 4. unDo (Undo the previous action)
    # 5. reDo ( Redo a undo-ed action)
    #
    # What is saved in the history:
    #  - current html content
    #  - current selection
    #  - current scrollbar position
    #  - the boolean newPosition
    ###

    ###* -----------------------------------------------------------------------
     *  Task history management

        time ------------------+------+---------------+-----------+-------->
        Tasks modified or      | T0c  | T0m T1c T2c   |  T1m T2m  |
        created                |      |               |           |
                               |      |               |           |
        History steps          H1     H2              H3          H4(*)
        history.modifiedTask        {T0c}       {T0m T1c T2c}   {T1m T2m}

        Ctrl-z                 H1     H2              H3(*)       H4
        _tasksToBeSaved                              {T1m,T2m}

        Ctrl-z                 H1     H2(*)           H3          H4
        _tasksToBeSaved              {T0m, T1d,T2d}

        Ctrl-z                 H1(*)  H2              H3          H4
        _tasksToBeSaved        {T0d, T1d,T2d}

        Ctrl-y                 H1     H2(*)           H3          H4
        _tasksToBeSaved              {T0m, T1d,T2d}

        Ctrl-y                 H1     H2              H3(*)       H4
        _tasksToBeSaved                              {T1m,T2m}

        Ctrl-y                 H1     H2              H3          H4(*)
        _tasksToBeSaved                                           {}

    ###



    ###* -----------------------------------------------------------------------
     * Add html, selection markers and scrollbar positions to the history.
     * No effect if the url popover is displayed
    ###
    addStep : () ->
        console.info '== _addHistory()'
        # do nothing if urlpopover is on, otherwise its html will also be
        # serialized in the history.
        if @editor.urlPopover.isOn or @editor._hotString.isPreparing
            return

        # 1- If some undo has been done, delete the steps forward (redo will
        # be then impossible)
        if @index < HISTORY_SIZE - 1
            i = HISTORY_SIZE - 1 - @index
            while i--
                @historySelect.pop()
                @historyScroll.pop()
                @historyPos.pop()
                @history.pop()
                @modifiedTask.pop()
                @historySelect.unshift(undefined)
                @historyScroll.unshift(undefined)
                @historyPos.unshift(undefined)
                @history.unshift(undefined)
                @modifiedTask.unshift(undefined)

        # 2- save selection
        @historySelect.push @editor.saveEditorSelection()

        # 3- save scrollbar position
        @historyScroll.push
            xcoord: @editor.linesDiv.scrollTop
            ycoord: @editor.linesDiv.scrollLeft

        # 4- save newPosition flag
        @historyPos.push @editor.newPosition

        # 5- add the html content with markers to the history
        @history.push @editor.linesDiv.innerHTML

        # 6- add the list of task modified since last addHistory()
        @modifiedTask.push @editor._tasksModifSinceLastHistory
        # console.info '  last @modifiedTask', @modifiedTask[@HISTORY_SIZE]
        @editor._tasksModifSinceLastHistory = {}

        # 7- update the index
        @index = HISTORY_SIZE - 1

        # 8- drop oldest history step
        @historySelect.shift()
        @historyScroll.shift()
        @historyPos.shift()
        @history.shift()
        @modifiedTask.shift()

        logging.printHistory '_addHistory', this

    removeLastStep : () ->
        @historySelect.pop()
        @historyScroll.pop()
        @historyPos.pop()
        @history.pop()
        @modifiedTask.pop()
        @historySelect.unshift(undefined)
        @historyScroll.unshift(undefined)
        @historyPos.unshift(undefined)
        @history.unshift(undefined)
        @modifiedTask.unshift(undefined)
        @index = HISTORY_SIZE - 1


    ### ------------------------------------------------------------------------
    #  undoPossible
    # Return true only if unDo can be called
    ###
    undoPossible : () ->
        result = (@index >= 0 && @historyPos[@index] != undefined )
        console.log 'undoPossible', result
        return result

    ### ------------------------------------------------------------------------
    #  redoPossible
    # Return true only if reDo can be called
    ###
    redoPossible : () ->
        return (@index < @history.length-2)