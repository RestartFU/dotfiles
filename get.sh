map=(\
	"mux"   "github.com/gorilla/mux" \
	"mongo" "go.mongodb.org/mongo-driver" \
	".env"  "github.com/joho/godotenv" \
)

for key in "${!map[@]}"
do
	if [[ "$1" == "${map[key]}" ]]; then
		go get "${map[key+1]}"
	fi
done
