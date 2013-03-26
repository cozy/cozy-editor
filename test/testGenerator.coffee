Recorder = require('views/recorder').Recorder
recorder = new Recorder()

exports.test = () ->

    describe 'recorder.randomTest', ->

        ###*
         * Var for the tests
        ###

        # The line used for the tests
        lineDiv = document.createElement('DIV')
        lineDiv.innerHTML =
        """
        <div id="CNID_1" class="Th-1"><span id="span10"><span id="span11">content1</span>content2</span><span id="span20"><span id="span21">content3</span></span><br></div>
        """
        # """ The line in a pretier format :
        # 
        # <div id="CNID_1" class="Th-1">
        #     <span id="span10">
        #         <span id="span11">content1</span>
        #         content2
        #     </span>
        #     <span id="span20">
        #         <span id="span21">content3</span>
        #     </span>
        #     <br>
        # </div>
        # """
        
        # references on each nodes of the line
        line     = lineDiv.firstChild
        span10   = line.firstChild
        span11   = span10.firstChild
        content1 = span11.firstChild
        content2 = span10.lastChild
        span20   = span10.nextSibling
        span21   = span20.firstChild
        content3 = span21.firstChild
        br       = line.lastChild

        ###
        All possible BP :

        <div id="CNID_1" class="Th-1">[BP1]
            <span id="span10">[BP2]
                <span id="span11">[BP3][BP4]c[BP5]ontent1[BP6][BP7]</span>[BP8]
                [BP9]c[BP10]ontent2[BP11][BP12]
            </span>[BP13]
            <span id="span20">[BP14]
                <span id="span21">[BP15][BP16]c[BP17]ontent3[BP18][BP19]</span>[BP20]
            </span>[BP21]
            <br>[BP22]
        </div>

        ###

        BP1  = 
               cont   : line
               offset : 0
        BP2  = 
               cont   : span10
               offset : 0
        BP3  = 
               cont   : span11
               offset : 0
        BP4  = 
               cont   : content1
               offset : 0
        BP5  = 
               cont   : content1
               offset : 1
        BP6  = 
               cont   : content1
               offset : 8
        BP7  = 
               cont   : span11
               offset : 1
        BP8  = 
               cont   : span10
               offset : 1
        BP9  = 
               cont   : content2
               offset : 0
        BP10 = 
               cont   : content2
               offset : 1
        BP11 = 
               cont   : content2
               offset : 8
        BP12 = 
               cont   : span10
               offset : 2
        BP13 = 
               cont   : line
               offset : 1
        BP14 = 
               cont   : span20
               offset : 0
        BP15 = 
               cont   : span21
               offset : 0
        BP16 = 
               cont   : content3
               offset : 0
        BP17 = 
               cont   : content3
               offset : 1
        BP18 = 
               cont   : content3
               offset : 8
        BP19 = 
               cont   : span21
               offset : 1
        BP20 = 
               cont   : span20
               offset : 1
        BP21 = 
               cont   : line
               offset : 2
        BP22 = 
               cont   : line
               offset : 3

        BPS = [BP1 ,BP2 ,BP3 ,BP4 ,BP5 ,BP6 ,BP7 ,BP8 ,BP9 ,BP10,BP11,BP12,BP13,BP14,BP15,BP16,BP17,BP18,BP19,BP20,BP21,BP22]

        findBP = (bp) ->
            for BP, i in BPS
                if BP.cont == bp.cont && BP.offset == bp.offset
                    return 'BP' + (i+1)



        ###*
         * The test of each fonctions for random selections :
        ###
        it "_getRandomStartLine", ->
            res = {}
            for i in [1..500]
                bp = recorder._getRandomStartLine(line)
                BPXX = findBP(bp)
                if res[BPXX]
                    res[BPXX] += 1
                else
                    res[BPXX] = 1

            theoricalRes = ['BP1', 'BP2', 'BP3', 'BP4']
            arr = []
            for prop, val of res
                arr.push(prop)
            expect(arr.length).to.be.equal(theoricalRes.length)
            expect( res[theoricalRes[0]] ).not.to.equal(undefined)
            expect( res[theoricalRes[1]] ).not.to.equal(undefined)
            expect( res[theoricalRes[2]] ).not.to.equal(undefined)
            expect( res[theoricalRes[3]] ).not.to.equal(undefined)


        it "_getRandomEndLine", ->
            res = {}
            for i in [1..500]
                bp = recorder._getRandomEndLine(line)
                BPXX = findBP(bp)
                if res[BPXX]
                    res[BPXX] += 1
                else
                    res[BPXX] = 1

            theoricalRes = ['BP18', 'BP19', 'BP20', 'BP21', 'BP22']
            arr = []
            for prop of res
                arr.push(prop)
            expect(arr.length).to.be.equal(theoricalRes.length)
            expect( res[theoricalRes[0]] ).not.to.equal(undefined)
            expect( res[theoricalRes[1]] ).not.to.equal(undefined)
            expect( res[theoricalRes[2]] ).not.to.equal(undefined)
            expect( res[theoricalRes[3]] ).not.to.equal(undefined)
            expect( res[theoricalRes[4]] ).not.to.equal(undefined)


        it "_getRandomMiddleLine", ->
            res = {}
            for i in [1..500]
                bp = recorder._getRandomMiddleLine(line)
                BPXX = findBP(bp)
                if res[BPXX]
                    res[BPXX] += 1
                else
                    res[BPXX] = 1

            theoricalRes = ['BP1' ,'BP2' ,'BP3' ,'BP4' ,'BP5' ,'BP6' ,'BP7' ,'BP8' ,'BP9' ,'BP10','BP11','BP12','BP13','BP14','BP15','BP16','BP17','BP18','BP19','BP20','BP21','BP22']
            arr = []
            for prop of res
                arr.push(prop)
            expect(arr.length).to.be.equal(theoricalRes.length)
            for i in [0..20]
                expect( res[theoricalRes[i]] ).not.to.equal(undefined)
            expect( res[theoricalRes[21]] ).not.to.equal(undefined)



        it "_selectRandomBP", ->
            res = {}
            for i in [1..500]
                bp = recorder._selectRandomBP(line)
                BPXX = findBP(bp)
                if res[BPXX]
                    res[BPXX] += 1
                else
                    res[BPXX] = 1

            theoricalRes = ['BP1' ,'BP2' ,'BP3' ,'BP4' ,'BP5' ,'BP6' ,'BP7' ,'BP8' ,'BP9' ,'BP10','BP11','BP12','BP13','BP14','BP15','BP16','BP17','BP18','BP19','BP20','BP21','BP22']
            arr = []
            for prop of res
                arr.push(prop)
            expect(arr.length).to.be.equal(theoricalRes.length)
            for i in [0..20]
                expect( res[theoricalRes[i]] ).not.to.equal(undefined)
            expect( res[theoricalRes[21]] ).not.to.equal(undefined)

        it '_randomChoice', ()->
            res = {}
            for i in [1..500]
                action = recorder._randomChoice(recorder.breakpointTypes)
                if res[action.type]
                    res[action.type] += 1
                else
                    res[action.type] = 1
            
            theoricalRes = ['start' ,'middle' ,'end']
            arr = []
            for prop of res
                arr.push(prop)
            expect(arr.length).to.be.equal(theoricalRes.length)
            for i in [0..1]
                expect( res[theoricalRes[i]] ).not.to.equal(undefined)
            expect( res[theoricalRes[2]] ).not.to.equal(undefined)

