require 'xcodeproj'
project_path = 'IsaretDiliCevirme.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'IsaretDiliCevirme' } || project.targets.first

# Find or create group
group = project.main_group.find_subpath('IsaretDiliCevirme', true)

# Remove old references if they exist
group.files.each do |file|
  if file.path == 'hos_geldiniz.gif'
    file.remove_from_project
  end
end

# Add file to group
file_ref = group.new_file('hos_geldiniz.gif')

# Add to target's "Copy Bundle Resources" build phase
resources_build_phase = target.resources_build_phase
resources_build_phase.add_file_reference(file_ref, true)

project.save
puts "Added hos_geldiniz.gif to Xcode project."
