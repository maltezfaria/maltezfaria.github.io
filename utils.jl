using TOML
using JSON
using Downloads
using Dates

function hfun_isactive(params)
    page = params[1]
    # Get the path of the current page
    current_page = Franklin.locvar("fd_rpath")
    # Check if the provided page path is a substring of the current page's path
    if startswith(current_page, page)
        return "active"
    end
    return ""
end

function hfun_teaching()
    data = TOML.parsefile("data.toml")
    teaching_entries = data["teaching"]
    sorted_entries = sort(teaching_entries, by=x -> x["year"], rev=true)

    io = IOBuffer()
    for course in sorted_entries
        write(io, "@@data-entry,teaching-entry\n**$(course["year"])**\n\n")

        title = course["title"]
        level = get(course, "level", "")
        location = get(course, "location", "")
        link = get(course, "link", "")

        details = title
        extra_info = filter(!isempty, [level, location])
        !isempty(extra_info) && (details *= " ($(join(extra_info, ", ")))")

        content = isempty(link) ? details : "[$details]($link)"
        write(io, content, "\n@@\n")
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end

function hfun_publications()
    data = TOML.parsefile("data.toml")
    pubs = data["publications"]

    # Group publications by category
    pubs_by_cat = Dict{String,Vector{Any}}()
    categories = String[]
    for pub in pubs
        cat = pub["category"]
        if !haskey(pubs_by_cat, cat)
            push!(categories, cat)
            pubs_by_cat[cat] = []
        end
        push!(pubs_by_cat[cat], pub)
    end

    io = IOBuffer()
    for cat in categories
        write(io, "#### $cat\n\n")
        sorted_pubs = sort(pubs_by_cat[cat], by=x -> x["year"], rev=true)

        for pub in sorted_pubs
            write(io, "@@data-entry,publication-entry\n**$(pub["year"])**\n\n")

            # Build description
            desc = "**$(pub["title"])**, $(pub["authors"]), _$(pub["publication"])_"

            # Add optional fields
            haskey(pub, "volume") && (desc *= ", vol. $(pub["volume"])")
            haskey(pub, "number") && (desc *= ", no. $(pub["number"])")
            haskey(pub, "pages") && (desc *= ", pp. $(pub["pages"])")
            desc *= "."

            # Build links
            links = String[]
            haskey(pub, "arxiv_link") && push!(links, "[arXiv]($(pub["arxiv_link"]))")
            haskey(pub, "hal_link") && push!(links, "[HAL]($(pub["hal_link"]))")
            haskey(pub, "url") && push!(links, "[DOI]($(pub["url"]))")
            haskey(pub, "pdf") && push!(links, "[PDF]($(pub["pdf"]))")
            haskey(pub, "code") && push!(links, "[code]($(pub["code"]))")

            !isempty(links) && (desc *= " [$(join(links, ", "))]")

            write(io, desc, "\n@@\n")
        end
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end

function hfun_codes()
    data = TOML.parsefile("data.toml")
    codes = get(data, "codes", [])
    io = IOBuffer()
    for code in codes
        repo = code["repo"]
        url = "https://api.github.com/repos/" * repo
        headers = ["User-Agent" => "Franklin-Website-Builder"]
        json_str = ""
        try
            json_str = Downloads.download(url, IOBuffer(); headers=headers) |> take! |> String
            repo_data = JSON.parse(json_str)
            name = repo_data["name"]
            description = get(repo_data, "description", "No description provided.")
            if description === nothing
                description = "No description provided."
            end
            description = get(code, "description_override", description)
            language = repo_data["language"]
            stars = repo_data["stargazers_count"]
            pushed_str = get(repo_data, "pushed_at", nothing)
            updated = if pushed_str !== nothing
                dt = DateTime(pushed_str, dateformat"yyyy-mm-ddTHH:MM:SSZ")
                Dates.format(dt, "yyyy-mm-dd")
            else
                "Unknown"
            end
            repo_url = repo_data["html_url"]

            write(io, "@@data-entry,code-entry\n")
            write(io, "@@code-left\n")
            write(io, "**[" * name * "](" * repo_url * ")**\n")
            write(io, "`[" * language * "]`\n")
            write(io, "@@\n")
            write(io, "@@code-right\n")
            write(io, description, "\n\n")
            write(io, "@@small ⭐ " * string(stars) * " | Updated: " * updated * "@@\n")
            write(io, "@@\n")
            write(io, "@@\n")
        catch e
            write(io, "@@data-entry,code-entry\n")
            write(io, "**Error fetching " * repo * "**\n\n")
            write(io, "Could not retrieve repository information from GitHub.\n")
            write(io, "@@\n")
        end
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end


function hfun_talks()
    data = TOML.parsefile("data.toml")
    talks = get(data, "talks", [])
    sorted_talks = sort(talks, by=x -> x["year"], rev=true)

    io = IOBuffer()
    for talk in sorted_talks
        write(io, "@@data-entry,talk-entry\n")
        write(io, "**$(talk["year"])**\n\n")

        desc = "**$(talk["title"])**, $(talk["event"]), _$(talk["location"])_"

        links = String[]
        haskey(talk, "slides") && push!(links, "[Slides]($(talk["slides"]))")
        haskey(talk, "video") && push!(links, "[Video]($(talk["video"]))")

        !isempty(links) && (desc *= " [$(join(links, ", "))]")

        write(io, desc, "\n@@\n")
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end

# Group entries by `category` (in order of first appearance), each group sorted by `start`
function _group_by_category(entries)
    groups = Dict{String,Vector{Any}}()
    categories = String[]
    for e in entries
        cat = e["category"]
        haskey(groups, cat) || (push!(categories, cat); groups[cat] = [])
        push!(groups[cat], e)
    end
    return [(cat, sort(groups[cat], by=x -> x["start"], rev=true)) for cat in categories]
end

function hfun_service()
    data = TOML.parsefile("data.toml")
    io = IOBuffer()
    for (cat, entries) in _group_by_category(get(data, "service", []))
        write(io, "#### $cat\n\n")
        for e in entries
            write(io, "@@data-entry,service-entry\n**$(e["period"])**\n\n")
            role = haskey(e, "link") ? "[$(e["role"])]($(e["link"]))" : e["role"]
            write(io, "$role, _$(e["organization"])_", "\n@@\n")
        end
    end
    journals = get(get(data, "refereeing", Dict()), "journals", [])
    if !isempty(journals)
        write(io, "#### Refereeing\n\nReviewer for $(join(journals, ", ")), among others.\n\n")
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end

function hfun_supervision()
    data = TOML.parsefile("data.toml")
    io = IOBuffer()
    for (cat, entries) in _group_by_category(get(data, "supervision", []))
        write(io, "#### $cat\n\n")
        for e in entries
            write(io, "@@data-entry,service-entry\n**$(e["period"])**\n\n")
            title = haskey(e, "link") ? "[$(e["title"])]($(e["link"]))" : e["title"]
            desc = "**$(e["name"])**, _$(title)_"
            haskey(e, "details") && (desc *= ". $(e["details"])")
            write(io, desc, ".\n@@\n")
        end
    end
    return Franklin.fd2html(String(take!(io)), internal=true)
end
