promote = [("Signins"
,50
,2000),

("Ringtones"
,150
,5000),

("Music Downloads"
,500
,30000),
  
("Posters"
,2000
,100000),

("Web Page"
,3000
,200000),

("T-Shirts"
,6000
,400000),

("Hoodies"
,10000
,1000000),

("Record a CD"
,25000
,2500000),

("Greatest Hits Album"
,90000
,10000000),

("Music Video"
,200000
,25000000),

("MTV Show"
,350000
,50000000)]

play = [("Street Corner"
,100,125
,10),

("Park"
,200,250
,15),

("Bar"
,300,600
,20),

("Casino"
,800,1200
,25),

("Opener"
,5000,6500
,30),

("Cruise Ship"
,10000,15000
,40)]



learn = [("Practice"
,1
,0
,5)

,("Jam"
,4
,0
,15)


,("Take a Lesson"
,6
,80
,20)


,("Lesson from a Pro"
,10
,2500
,30)


,("Garage Jam"
,12
,0
,40)


,("Compose"
,35
,20000
,100)

,("Work with a Producer"
,80
,100000
,200)]

print "Promote (min)"
for i in promote:
    print "\t%s %s %d" % (i[0], " "*(30-len(i[0])), i[2]/i[1])
print "Play (max)"
for i in play:
    print "\t%s %s %d-%d" % (i[0], " "*(30-len(i[0])), i[1]/i[3], i[2]/i[3])
print "Learn (min)"
for i in learn:
    print "\t%s %s %d-%d" % (i[0], " "*(30-len(i[0])+(4-len(str(i[2]/i[1])))), i[2]/i[1], 10*float(i[3])/i[1])
