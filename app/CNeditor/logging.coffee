console.info = ->
    # console.log.apply console, arguments

module.exports =

    ###* -----------------------------------------------------------------------
     * A utility fuction for debugging
     * @param  {string} txt A text to print in front of the log
    ###
    printHistory : (txt, history) ->
        if ! txt
            txt = ''
        console.info txt + ' _history.index : ' + history.index
        for step, i in history.history
            if history.index == i
                arrow = ' <---'
            else
                arrow = ' '
                content = $(step).text()
                content = '_' if content == ''
            console.info i, content , history.historySelect[i] , arrow
        return true


    ###* -----------------------------------------------------------------------
     * A utility fuction for debugging
     * @param  {string} txt A text to print in front of the log
    ###
    printTasksModifStacks : (txt, _tasksToBeSaved) ->
        if ! txt
            txt = ''
        res =  '  _tasksToBeSaved : '
        for id, modif of _tasksToBeSaved
            res += id + ':'
            if modif.created
                res += 'created-'
            if modif.modified
                res += 'modified-'
            if modif.deleted
                res += 'deleted-'
            if modif.removed
                res += 'removed-'
            res = res.slice(0,-1)
            res +=  ', '
        res = res.slice(0,-2)
        console.info res
        return true