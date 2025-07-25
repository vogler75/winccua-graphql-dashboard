cmake_minimum_required(VERSION 3.10)
project(winccunified C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

find_package(CURL REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CJSON REQUIRED libcjson)

include_directories(include)

set(SOURCES
    src/graphql_client.c
    src/wincc_unified.c
)

add_library(winccunified STATIC ${SOURCES})
target_link_libraries(winccunified ${CURL_LIBRARIES} ${CJSON_LIBRARIES})
target_include_directories(winccunified PUBLIC ${CURL_INCLUDE_DIRS} ${CJSON_INCLUDE_DIRS})

add_executable(basic_usage examples/basic_usage.c)
target_link_libraries(basic_usage winccunified)

add_executable(monitor_tags examples/monitor_tags.c)
target_link_libraries(monitor_tags winccunified)

install(TARGETS winccunified ARCHIVE DESTINATION lib)
install(DIRECTORY include/ DESTINATION include/winccunified)

enable_testing()
add_test(NAME basic_usage_test COMMAND basic_usage)