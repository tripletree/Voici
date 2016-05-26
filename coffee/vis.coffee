
root = exports ? this

Bubbles = () ->
  # standard variables accessible to
  # the rest of the functions inside Bubbles
  width = 1080
  height = 450
  data = []
  node = null
  label = null
  margin = {top: 0, right: 0, bottom: 0, left: 0}
  # largest size for our bubbles
  maxRadius = 100

  # this scale will be used to size our bubbles
  rScale = d3.scale.sqrt().range([0,maxRadius])
  
  # I've abstracted the data value used to size each
  # into its own function. This should make it easy
  # to switch out the underlying dataset
  rValue = (d) -> parseInt(d.count)

  # function to define the 'id' of a data element
  #  - used to bind the data uniquely to the force nodes
  #   and for url creation
  #  - should make it easier to switch out dataset
  #   for your own
  idValue = (d) -> d.name

  # function to define what to display in each bubble
  #  again, abstracted to ease migration to 
  #  a different dataset if desired
  textValue = (d) -> d.name

  # constants to control how
  # collision look and act
  collisionPadding = 26
  minCollisionRadius = 12

  # variables that can be changed
  # to tweak how the force layout
  # acts
  # - jitter controls the 'jumpiness'click
  #  of the collisions
  jitter = 0.7

  # ---
  # tweaks our dataset to get it into the
  # format we want
  # - for this dataset, we just need to
  #  ensure the count is a number
  # - for your own dataset, you might want
  #  to tweak a bit more
  # ---
  transformData = (rawData) ->
    rawData.forEach (d) ->
      d.count = parseInt(d.count)
      rawData.sort(() -> 0.5 - Math.random())
    rawData

  # ---
  # tick callback function will be executed for every
  # iteration of the force simulation
  # - moves force nodes towards their destinations
  # - deals with collisions of force nodes
  # - updates visual bubbles to reflect new force node locations
  # ---
  tick = (e) ->
    dampenedAlpha = e.alpha * 0.1
    
    # Most of the work is done by the gravity and collide
    # functions.
    node
      .each(gravity(dampenedAlpha))
      .each(collide(jitter))
      .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    # As the labels are created in raw html and not svg, we need
    # to ensure we specify the 'px' for moving based on pixels
   # label
    #  .style("left", (d) -> ((margin.left + d.x) - d.dx / 2) + "px")
    #  .style("top", (d) -> ((margin.top + d.y) - d.dy / 2) + "px")

  # The force variable is the force layout controlling the bubbles
  # here we disable gravity and charge as we implement custom versions
  # of gravity and collisions for this visualization
  force = d3.layout.force()
    .gravity(0)
    .charge(0)
    .size([width, height])
    .on("tick", tick)

  # ---
  # Creates new chart function. This is the 'constructor' of our
  #  visualization
  # Check out http://bost.ocks.org/mike/chart/ 
  #  for a explanation and rational behind this function design
  # ---
  chart = (selection) ->
    selection.each (rawData) ->

      # first, get the data in the right format
      data = transformData(rawData)
      # setup the radius scale's domain now that
      # we have some data
      maxDomainValue = d3.max(data, (d) -> rValue(d))
      rScale.domain([0, maxDomainValue])

      # a fancy way to setup svg element
      svg = d3.select(this).selectAll("svg").data([data])
      svgEnter = svg.enter().append("svg")
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )
      
      # node will be used to group the bubbles
      node = svgEnter.append("g").attr("id", "bubble-nodes")
       .attr("transform", "translate(#{margin.left},#{margin.top})")



      # clickable background rect to clear the current selection
 

      # label is the container div for all the labels that sit on top of 
      # the bubbles
      # - remember that we are keeping the labels in plain html and 
      #  the bubbles in svg
      #label = d3.select(this).selectAll("#bubble-labels").data([data])
        #.enter()
       # .append("div")
        #.attr("id", "bubble-labels")

      update()

     
  # ---
  # update starts up the force directed layout and then
  # updates the nodes and labels
  # ---
  update = () ->
    # add a radius to our data nodes that will serve to determine
    # when a collision has occurred. This uses the same scale as
    # the one used to size our bubbles, but it kicks up the minimum
    # size to make it so smaller bubbles have a slightly larger 
    # collision 'sphere'
    data.forEach (d,i) ->
      d.forceR = Math.max(minCollisionRadius, rScale(rValue(d)))

    # start up the force layout
    force.nodes(data).start()

    # call our update methods to do the creation and layout work
    updateNodes()
    #updateLabels()

  # ---
  # updateNodes creates a new bubble for each node in our dataset
  # ---
  updateNodes = () ->
    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    node = node.selectAll("g").data(data)

    # we don't actually remove any nodes from our data in this example 
    # but if we did, this line of code would remove them from the
    # visualization as well
    node.exit().remove()

    # nodes are just links with circles inside.
    # the styling comes from the css
    nodeEnter = node.enter().append("g") .call(force.drag)
      .call(connectEvents)
   

    nodeEnter.append("circle")
      .attr("r", (d) -> rScale(rValue(d)))
      .attr("class", "bubble-node")

    nodeEnter.append("text")
      .text((d) -> textValue(d))
      .attr("class", "bubble-label")
      .attr("dy", "0.3em")
      .style("text-anchor", "middle")



  
  # ---
  # custom gravity to skew the bubble placement
  # ---
  gravity = (alpha) ->
    # start with the center of the display
    cx = width / 2
    cy = height / 2
    # use alpha to affect how much to push
    # towards the horizontal or vertical
    ax = alpha / 8
    ay = alpha

    # return a function that will modify the
    # node's x and y values
    (d) ->
      d.x += (cx - d.x) * ax
      d.y += (cy - d.y) * ay

  # ---
  # custom collision function to prevent
  # nodes from touching
  # This version is brute force
  # we could use quadtree to speed up implementation
  # (which is what Mike's original version does)
  # ---
  collide = (jitter) ->
    # return a function that modifies
    # the x and y of a node
    (d) ->
      data.forEach (d2) ->
        # check that we aren't comparing a node
        # with itself
        if d != d2
          # use distance formula to find distance
          # between two nodes
          x = d.x - d2.x
          y = d.y - d2.y
          distance = Math.sqrt(x * x + y * y)
          # find current minimum space between two nodes
          # using the forceR that was set to match the 
          # visible radius of the nodes
          minDistance = d.forceR + d2.forceR + collisionPadding

          # if the current distance is less then the minimum
          # allowed then we need to push both nodes away from one another
          if distance < minDistance
            # scale the distance based on the jitter variable
            distance = (distance - minDistance) / distance * jitter
            # move our two nodes
            moveX = x * distance
            moveY = y * distance
            d.x -= moveX
            d.y -= moveY
            d2.x += moveX
            d2.y += moveY

  # ---
  # adds mouse events to element
  # ---
  connectEvents = (d) ->
    d.on("click", click)
    d.on("mouseover", mouseover)
    d.on("mouseout", mouseout)

  # ---
  # clears currently selected bubble
  # ---
 

  # ---
  # changes clicked bubble by modifying url
  # ---
  click = (d) ->
    d3.select(this.firstChild).classed("bubble-selected",true)
    d3.event.preventDefault()

  # ---
  # called when url after the # changes
  # ---


  # ---
  # hover event
  # ---
  mouseover = (d) ->
     d3.select(this.firstChild).classed("bubble-hover", (p) -> p == d)
       
        .transition()
        .duration(100)
        .ease("sin")
        .attr("r",(d) -> 1.1*rScale(rValue(d)))

  # ---
  # remove hover class
  # ---
  mouseout = (d) ->
   d3.select(this.firstChild).classed("bubble-hover", false)
      .transition()
      .duration(100)
      .ease("sin")
      .attr("r",(d) ->rScale(rValue(d)))

  # ---
  # public getter/setter for jitter variable
  # ---
  chart.jitter = (_) ->
    if !arguments.length
      return jitter
    jitter = _
    force.start()
    chart

  # ---
  # public getter/setter for height variable
  # ---
  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  # ---
  # public getter/setter for width variable
  # ---
  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  # ---
  # public getter/setter for radius function
  # ---
  chart.r = (_) ->
    if !arguments.length
      return rValue
    rValue = _
    chart
  
  # final act of our main function is to
  # return the chart function we have created
  return chart

# ---
# Helper function that simplifies the calling
# of our chart with it's data and div selector
# specified
# ---
root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)
# ---
# jQuery document ready.
# ---
$ ->
  # create a new Bubbles chart
  plot = Bubbles()

  # ---
  # function that is called when
  # data is loaded
  # ---
  display = (data) ->
    plotData("#vis", data, plot)

 
  # load our data
  d3.csv("data/top_sherlock.csv", display)

