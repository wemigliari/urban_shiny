

library(shiny)
library(dplyr)
library(leaflet)
library(RColorBrewer)
library(tmap)
library(readxl)
library(xlsx)
library(writexl)
library(purrr)


data("metro")
metro_coor <- metro %>% mutate(lat = unlist(map(metro$geometry,2)), long = unlist(map(metro$geometry,1)))
growth <- c(metro_coor$pop2030 - metro_coor$pop2020)

read_excel("metro_coord.xlsx")
metro_coord <- cbind(metro_coor, growth)
metro_coord <- data.frame(metro_coord)

ui <- bootstrapPage(
    tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
    leafletOutput("map", width = "100%", height = "100%"),
    absolutePanel(top = 10, right = 10,
                  sliderInput("range", "Metropolitan Growth", min(metro_coord$growth), max(metro_coord$growth),
                              value = range(metro_coord$growth), step = 0.1
                  ),
                  selectInput("colors", "Color Scheme",
                              rownames(subset(brewer.pal.info, category %in% c("seq", "div")))
                  ),
                  checkboxInput("legend", "Show legend", TRUE)
    )
)

server <- function(input, output, session) {
    
    # Reactive expression for the data subsetted to what the user selected
    filteredData <- reactive({
        metro_coord[metro_coord$growth >= input$range[1] & metro_coord$growth <= input$range[2],]
    })
    
    # This reactive expression represents the palette function,
    # which changes as the user makes selections in UI.
    colorpal <- reactive({
        colorNumeric(input$colors, metro_coord$growth)
    })
    
    output$map <- renderLeaflet({
        # Use leaflet() here, and only include aspects of the map that
        # won't need to change dynamically (at least, not unless the
        # entire map is being torn down and recreated).
        leaflet(metro_coord) %>% addTiles()
    })
    
    # Incremental changes to the map (in this case, replacing the
    # circles when a new color is chosen) should be performed in
    # an observer. Each independent set of things that can change
    # should be managed in its own observer.
    observe({
        pal <- colorpal()
        
        leafletProxy("map", data = filteredData()) %>%
            clearShapes() %>%
            setView(40,50, 2)%>%
            addProviderTiles(providers$Esri)%>%
            addCircles(metro_coord, lat = metro_coord$lat, lng = metro_coord$long,radius = ~growth/30, weight = 1, color = "black",
                       fillColor = ~pal(metro_coord$growth), fillOpacity = 0.6, popup = ~paste(metro_coord$growth)
            )
    })
    
    # Use a separate observer to recreate the legend as needed.
    observe({
        proxy <- leafletProxy("map", data = metro_coord)
        
        # Remove any existing legend, and only if the legend is
        # enabled, create a new one.
        proxy %>% clearControls()
        if (input$legend) {
            pal <- colorpal()
            proxy %>% addLegend(position = "bottomright",
                                pal = pal, values = ~growth
            )
        }
    })
}

shinyApp(ui, server)

